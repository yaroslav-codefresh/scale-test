# Maven Central Rate Limiting — Investigation & Response

---

## 1. Problem Statement

Codefresh (Octopus) operates a SaaS CI/CD platform where all customer pipelines on shared
runtimes share a single egress IP (**3.232.154.67** via AlterNAT). Customer builds download
Maven artifacts directly from Maven Central on every run, with no caching layer. From Maven
Central's perspective, this single IP generates enormous traffic — **2.0M downloads in 7 days**,
1.98M of which were avoidable with caching.

Sonatype has begun rolling out stricter, industry-wide rate limits, and our shared IP is now
hitting those limits. We have no control over what customers build and cannot intercept or
reroute their artifact downloads. When we are blocked, **all customers on shared SaaS runtimes
who use Maven fail simultaneously**.

---

## 2. Incident Summary & Timeline

On May 12, 2026, customers began receiving HTTP **429 Too Many Requests** errors when pulling
Maven artifacts from `repo.maven.apache.org`, causing CI/CD pipeline failures.

| Time (CEST)       | Event                                                                                    |
|-------------------|------------------------------------------------------------------------------------------|
| May 12, ~14:00    | First customer tickets: sashajo, pipelinespotpower, xmldation                            |
| May 12, 14:13     | Jira bug CR-40592 created                                                                |
| May 12, 14:29     | Identified as Maven Sonatype IP-based rate limiting                                      |
| May 12, 16:37     | Email sent to Sonatype support (central-support@sonatype.com)                            |
| May 12, 18:03     | Correct egress IP 3.232.154.67 identified and shared with Sonatype                      |
| May 12, 19:48     | 4th customer report (Verimatrix); status page incident created                           |
| May 12, 21:55     | Sonatype temporarily unblocks our IP; builds resume                                      |
| May 14            | Sonatype confirms permanent unblock while commercial discussions continue                 |
| May 16            | Sonatype provides commercial proposal ($25K/year) and answers our questions              |
| May 18            | Second wave — one customer hits a personal/org-level rate limit from aggressive retries  |

> **Key finding:** Rate limiting is not purely IP-based. Sonatype also applies **organisational
> behaviour patterns**. A customer who aggressively retried failed builds triggered a personal
> rate limit even when the platform IP was unblocked.

---

## 3. Background: Maven Repository & Caching Proxy

**Maven Repository (Maven Central)** is the primary public artifact registry for the JVM/Java
ecosystem. Build tools like Maven and Gradle fetch dependencies from it on every build. It is
operated by Sonatype, free to use, but not designed to scale for CI farms hitting it directly
without caching.

**Maven Repository Proxy (Caching Proxy)** is an intermediary server (e.g. Nexus, Artifactory,
AWS CodeArtifact, GCP Artifact Registry) that sits between the build agent and Maven Central.
On the first request for an artifact, the proxy downloads and caches it. All subsequent requests
for the same artifact are served from the cache, eliminating redundant traffic to Maven Central.
This is the standard pattern for enterprise build environments.

Setting it up requires: deploying or subscribing to a proxy service, pointing
`~/.m2/settings.xml` to it, and optionally updating `pom.xml`. Only the `settings.xml` change
is strictly required for caching public Maven Central artifacts.

Sonatype's own recommendation — and the industry standard — is for all CI/CD platforms to use
a caching proxy rather than hitting Maven Central directly on every build.

---

## 4. Current Impact Radius

The table below shows all customers using Maven in their pipelines (April 2026, from CF-1843).
Customers on **hybrid runners** use their own egress IPs and are **not affected** by our shared
IP rate limit. Only customers on shared SaaS runtimes are exposed.

| Account                        | Plan         | Builds/Month | Runtime                                         | At Risk? |
|--------------------------------|--------------|--------------|-------------------------------------------------|----------|
| wwt                            | SILVER       | 19,797       | Hybrid (own runner)                             | No       |
| pismo                          | SILVER       | 14,946       | Hybrid (own runner)                             | No       |
| ip-prod                        | PLATINUM     | 6,692        | Hybrid                                          | No       |
| forgecloud                     | SILVER       | 4,956        | Hybrid                                          | No       |
| regnosysops                    | SILVER       | 3,565        | system/codefresh-enterprise                     | **Yes**  |
| capsule                        | SILVER       | 2,291        | Hybrid                                          | No       |
| sashajo                        | SILVER       | 1,162        | system/linux_paying_plan                        | **Yes**  |
| crossix.veeva                  | SILVER       | 856          | Hybrid                                          | No       |
| asapp                          | PROFESSIONAL | 628          | Hybrid                                          | No       |
| judo                           | SILVER       | 633          | system/plan/linux                               | **Yes**  |
| ipp-engenharia-cloud           | SILVER       | 632          | system/linux_paying_plan                        | **Yes**  |
| armadillo-financial-technology | SILVER       | 563          | Hybrid (arm64)                                  | No       |
| identiq                        | SILVER       | 365          | system/linux_paying_plan                        | **Yes**  |
| guardanthealth                 | GOLD         | 361          | Hybrid                                          | No       |
| ip-dev                         | PLATINUM     | 431          | Hybrid                                          | No       |
| weedmaps                       | GOLD         | 260          | Hybrid                                          | No       |
| yellowbrickdata                | SILVER       | 217          | Hybrid                                          | No       |
| omnicell                       | SILVER       | 204          | system/codefresh-enterprise                     | **Yes**  |
| verimatrix                     | SILVER       | 166          | system/linux_paying_plan                        | **Yes**  |
| spaceiq                        | SILVER       | 161          | Hybrid                                          | No       |
| goodrx                         | PLATINUM     | 116          | Hybrid                                          | No       |
| liber-ufpe                     | FREE         | 110          | system/linux_non_paying_plan                    | **Yes**  |
| xmldation                      | SILVER       | 99           | system/linux_paying_plan                        | **Yes**  |
| pipelinespotpower              | SILVER       | 97           | system/linux_paying_plan                        | **Yes**  |
| bankunited                     | PROFESSIONAL | 89           | Hybrid                                          | No       |
| legalshieldcorp                | SILVER       | 67           | system/linux_paying_plan                        | **Yes**  |
| sojern                         | PLATINUM     | 86           | system/codefresh-enterprise-volume-per-pipeline | **Yes**  |
| laurent-cf                     | SILVER       | 83           | system/linux_paying_plan                        | **Yes**  |
| verizon-act                    | PROFESSIONAL | 50           | Hybrid                                          | No       |
| irhythm-prod                   | PROFESSIONAL | 48           | Hybrid                                          | No       |
| verizon-act                    | PROFESSIONAL | 50           | Hybrid                                          | No       |
| peterchiudb                    | SILVER       | 24           | system/linux_non_paying_plan                    | **Yes**  |
| otus-china                     | SILVER       | 11           | system/linux_paying_plan                        | **Yes**  |
| chumba                         | SILVER       | 15           | system/linux_paying_plan                        | **Yes**  |
| hobsons                        | PLATINUM     | 5            | system/linux_paying_plan                        | **Yes**  |
| endare                         | SILVER       | 3            | system/linux_paying_plan                        | **Yes**  |
| maybank                        | FREE         | 1            | undefined                                       | Unknown  |

### Maven Builds — Single Day Sample (May 20, 2026)

901 builds executed using Maven commands across 10 customers:

| Account                        | Plan         | Maven Builds |
|--------------------------------|--------------|--------------|
| wwt                            | SILVER       | 812          |
| sojern                         | PLATINUM     | 29           |
| armadillo-financial-technology | SILVER       | 23           |
| ipp-engenharia-cloud           | SILVER       | 15           |
| weedmaps                       | GOLD         | 8            |
| spaceiq                        | SILVER       | 4            |
| bankunited                     | PROFESSIONAL | 4            |
| regnosysops                    | SILVER       | 3            |
| peterchiudb                    | SILVER       | 2            |
| irhythm-prod                   | PROFESSIONAL | 1            |

> **Note:** wwt (812 of 901 Maven builds) is on a hybrid runner and does not contribute to our
> shared IP traffic. The at-risk SaaS population by Maven build volume is much smaller.

---

## 5. Possible Solutions

### Option 1: Pay Sonatype — Commercial License

**Who acts:** Octopus/Codefresh pays on behalf of all customers.

Sonatype has introduced a commercial licensing model for infrastructure providers and CI/CD
platforms that depend on Maven Central. Their position: commercial usage of Maven Central as
infrastructure warrants a commercial relationship.

#### Cost

| Item        | Detail                                                                                              |
|-------------|-----------------------------------------------------------------------------------------------------|
| Lowest tier | **$25,000/year** (annual, confirmed)                                                                |
| Our tier    | Based on IP 3.232.154.67 alone we fall in the lowest tier. Full proposal requires all egress IPs.   |

#### What we get

- Permanent whitelist for our egress IPs
- No further reactive incidents
- No changes required on the customer side
- Sonatype holds blocks while we engage in good faith

#### What we don't get

- Any caching benefit — builds still hit Maven Central on every run
- Protection against per-customer / org-level rate limits (separate mechanism)

**Status:** Sonatype's Brian (Co-founder/CTO) offered a call. No decision made.
They will hold the block *"in weeks not months."*

**Verdict:** Operationally the simplest solution. Reasonable cost relative to engineering
alternatives. Does not fix the root cause but eliminates incident risk.

---

### Option 2: Octopus-Managed Maven Caching Proxy

**Who acts:** Octopus builds, hosts, and maintains a proxy for all SaaS customers.

Technically feasible, but Sonatype explicitly told us: *"It is actually pretty difficult to get
all the traffic routed because you don't control what the customers build."* This applies to
curl scripts, Gradle wrappers, React Native builds, etc.

#### Infrastructure Cost Estimate (800 builds/day)

| Component                       | Monthly Cost                    |
|---------------------------------|---------------------------------|
| EC2 m6i.xlarge (4 vCPU, 16 GB) | $140                            |
| EBS 500 GB gp3                  | $40                             |
| Data egress ~3.5 TB             | $315                            |
| **Total infra**                 | **~$495/month (~$5,940/year)**  |

#### Tool Licensing (additional)

| Tool                    | Price           |
|-------------------------|-----------------|
| Nexus OSS               | Free            |
| Nexus Pro               | $1,620/year     |
| Artifactory Pro X       | $27,000/year    |
| Artifactory Enterprise X | $51,000/year   |

**Verdict:** High engineering effort, high operational risk, unlikely to achieve full traffic
coverage. Not recommended in the short or medium term.

---

### Option 3: Customer-Side Caching Proxy

**Who acts:** Each customer sets up their own caching proxy. Codefresh provides documentation
and guidance. Zero engineering effort for us.

**How it works:** First build per unique artifact fetches from Maven Central and caches locally.
All subsequent builds serve from cache — rate limits are no longer triggered from our shared IP.

**What customers need to change:**

- Add proxy URL to `~/.m2/settings.xml` (one line)
- Optionally update `pom.xml` `<repositories>` section
- Configure authentication for their chosen proxy (varies by provider)

> **Who this does NOT work for:** Small Pro/Silver SaaS-only customers with no cloud
> infrastructure (pipelinespotpower, xmldation, legalshieldcorp). For them, Option 1 or
> Option 4 are the only paths.

#### Sub-option A: Self-Hosted Nexus / Artifactory

**Best for:** Customers with an existing Kubernetes cluster (hybrid runner users).

**Setup steps:**
1. Deploy Nexus or Artifactory via Helm to their cluster
2. Configure a Maven proxy repository pointing to Maven Central  
   *(UI: Repositories → Create → maven2(proxy))*
3. Update `~/.m2/settings.xml` with proxy URL

| Component                                     | Cost                          |
|-----------------------------------------------|-------------------------------|
| Nexus OSS license                             | Free                          |
| Nexus Pro license                             | $1,620/year                   |
| Artifactory Pro X license                     | $27,000/year                  |
| Artifactory Enterprise X license              | $51,000/year                  |
| Infrastructure (EC2 + EBS + egress, 800/day)  | ~$495/month (~$5,940/year)    |

**Verdict:** Good fit for SILVER/GOLD/PLATINUM customers with dedicated infrastructure.
Nexus OSS + infra is the most common pattern. Not viable for SaaS-only customers.

#### Sub-option B: AWS CodeArtifact

**Best for:** Customers running hybrid runners on AWS.

AWS CodeArtifact supports Maven Central as an upstream source. First request fetches and
caches; subsequent requests are served from CodeArtifact. Main friction: authentication
requires generating a short-lived token via AWS CLI before each build.

| Component                                   | Price                              |
|---------------------------------------------|------------------------------------|
| Free tier (always-on)                       | 2 GB storage + 100K requests/month |
| Storage                                     | $0.05/GB-month                     |
| Requests                                    | $0.05 per 10,000 requests          |
| Data transfer (same AWS region)             | Free                               |
| **Estimated total (moderate CI, post-warmup)** | **~$10–30/month**               |
| Small teams (<100K requests/month)          | Free                               |

**Verdict:** Very low cost for AWS customers. Main friction is auth token setup in pipelines.

#### Sub-option C: Google Artifact Registry (Remote Repository)

**Best for:** Customers running on GCP.

GCP Artifact Registry has native support for Remote Repositories — a Maven Central proxy.
One CLI command creates it. No per-request billing; costs are storage and egress only.

**Setup (single command):**

```bash
gcloud artifacts repositories create my-maven-proxy \
  --repository-format=maven \
  --location=us-east1 \
  --mode=remote-repository \
  --remote-mvn-repo=MAVEN-CENTRAL
```

| Component                                      | Price                          |
|------------------------------------------------|--------------------------------|
| Storage (first 0.5 GB)                         | Free                           |
| Storage (over 0.5 GB)                          | $0.10/GB-month                 |
| Egress within GCP same region                  | Free                           |
| Egress to non-GCP clients                      | $0.12–$0.23/GB                 |
| API operations (pulls/pushes)                  | Free                           |
| **Estimated total (post-warmup, 50–100 GB cache)** | **~$5–20/month**           |

**Verdict:** Cheapest managed option for GCP customers. Near-zero operational overhead.

#### Sub-option D: Azure Artifacts

**Best for:** Customers already using Azure DevOps.

Azure Artifacts supports Maven feeds with upstream sources pointing to Maven Central.
For customers already on Azure DevOps, this is effectively free.

| Component                            | Price                          |
|--------------------------------------|--------------------------------|
| Storage (first 2 GiB)                | Free                           |
| Storage (additional)                 | ~$2/GiB                        |
| Per-request charges                  | None                           |
| User licensing (first 5 users)       | Free                           |
| User licensing (additional)          | $6/user/month (AzDO Basic)     |
| **Estimated total (existing AzDO customer)** | **~$0–10/month**       |

**Verdict:** Zero-cost for existing Azure DevOps users. Over-engineered for anyone not
already in the Microsoft ecosystem.

#### Sub-option E: JFrog Artifactory Cloud

**Best for:** Customers wanting a standalone, cloud-agnostic managed proxy.

JFrog Artifactory supports remote Maven repositories with advanced features (vulnerability
scanning, policy enforcement, etc.). However, its **consumption-based pricing** combines
storage and data transfer into a single meter, making it expensive for CI-heavy teams.

| Plan                        | Base Price    | Included                         | Overage    |
|-----------------------------|---------------|----------------------------------|------------|
| Pro (SaaS)                  | $150/month    | 25 GB combined storage + transfer | $1.25/GB  |
| Enterprise X (SaaS)         | $950/month    | 125 GB combined                  | $1.00/GB   |
| Pro X (self-hosted)         | $27,000/year  | 1 server                         | —          |
| Enterprise X (self-hosted)  | $51,000/year  | 3 servers                        | —          |

**Real-world cost example** (50 builds/day, 200 MB/build):
100 GB storage + 300 GB transfer = 400 GB/month → $150 base + 375 GB × $1.25 ≈ **$619/month**

**Verdict:** Powerful product but expensive for CI use cases. Not recommended unless the
customer already has an Artifactory subscription.

#### Summary: All Customer-Side Proxy Options

| Option                  | Maven Central Proxy?       | Best Fit                   | Est. Monthly Cost  | Setup Effort          |
|-------------------------|----------------------------|----------------------------|--------------------|-----------------------|
| Self-hosted Nexus OSS   | Yes                        | Any customer with own K8s  | ~$495 (infra only) | Medium                |
| AWS CodeArtifact        | Yes                        | AWS-based customers        | $0–30              | Medium (auth tokens)  |
| GCP Artifact Registry   | Yes                        | GCP-based customers        | $5–20              | Low (1 CLI command)   |
| Azure Artifacts         | Yes                        | Azure DevOps customers     | $0–10              | Low (if on AzDO)      |
| JFrog Artifactory Cloud | Yes                        | Any (standalone SaaS)      | $150–700+          | Low-Medium            |
| GitHub Packages         | No (private artifacts only)| N/A for this use case      | N/A                | N/A                   |

---

### Option 4: Hybrid Runner Migration

**Who acts:** Move affected SaaS customers to hybrid runners (their own infrastructure).

This removes customers from our shared IP entirely. Their builds hit Maven Central from their
own IPs, and rate limits apply per-organisation rather than across all of Codefresh.

- **Viable for:** Enterprise-tier customers with DevOps capacity
- **Not viable for:** Small Pro/Silver customers — no infrastructure, not in their contract

**Verdict:** Good long-term recommendation for larger customers regardless of this incident.
Not a short-term fix, and not available to the most vulnerable (smallest) customers.

---

## 6. Sonatype Email Thread — Key Points

The full email thread (started May 12, 2026, subject: *"We're getting HTTP 429 errors from
Maven"*) spans 19 messages. Key points:

### Traffic Report — IP 3.232.154.67 (7-day window)

| Metric                                      | Value                          |
|---------------------------------------------|--------------------------------|
| Unique Maven components downloaded          | 18,665                         |
| Average downloads per component             | 107×                           |
| Total downloads                             | 2.0M                           |
| Avoidable downloads (with a repo manager)   | 1.98M (99%)                    |
| Repository manager in use                   | None — 100% direct client      |
| Apache Maven share of traffic               | 75.9% (1,515,387 downloads)    |

### Sonatype's Position

> *"We are working with other package registries to jointly try to bring balance back into the
> ecosystem and make this all more sustainable. As a result, newer rate limits have started to
> be introduced."*

> *"As part of the sustainability roll out, the terms of service call out commercial usage of
> the repository as something we should engage in commercial terms for. We have been asking
> infrastructure and other companies that build services which depend directly on the public
> registry to help pay to support that infrastructure. The lowest tier for this engagement is
> $25K and is meant to be easily consumable."*

### Q&A (May 16 Response)

| Question                                                             | Sonatype Answer                                                                                                                                                     |
|----------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Is $25K monthly or annual?                                           | Annual.                                                                                                                                                             |
| Can customers use a paid token to reduce our IP's rate limit impact? | "There is no mechanism for individual users to purchase a token. Even if there were, given the dispersion of the tools, it would be impossible to get all tools to use it." |
| How long are we unblocked before rate limiting returns?              | "Provided we continue to move forward in good faith, we will hold the blocks, but we should be moving through the process in weeks not months."                      |
| What is the cost/effort of a caching proxy as an alternative?        | "Probably comparable but could be more expensive. In discussions with other similar providers, it is actually pretty difficult to get all the traffic routed because you don't control what the customers build." |

Sonatype's Brian (Co-founder/CTO) offered a call to discuss further.

---

## 7. Open Questions

| # | Question                                                         | Why It Matters                                                                                                        |
|---|------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|
| 1 | Decision on the Sonatype $25K/year deal?                         | They are holding our block in good faith for "weeks not months." We need to decide or negotiate soon.                 |
| 2 | What are all our egress IPs across clusters and regions?         | Sonatype needs the full list to size the commercial proposal. We only provided 3.232.154.67 so far.                   |
| 3 | What is the actual deadline before they re-enable rate limiting? | "Weeks not months" is vague. We need a concrete date to plan against.                                                 |
| 4 | Can we appeal individual-customer org-level blocks?              | May 18 showed a customer hit a personal rate limit via retry storms, independent of the IP. Unclear if Sonatype support can help. |
| 5 | Does Maven Profile dynamic switching work in practice?           | CF-1829 mentions switching between Maven Central and a proxy via Maven Profiles + env vars. Needs validation before including in customer guidance. |
| 6 | Do we have precise Maven build volume per SaaS-runtime customer? | Current data mixes hybrid and SaaS customers. We need SaaS-only Maven build counts to accurately size the risk.       |
| 7 | Should a caching proxy become a Codefresh platform feature?      | No peer CI/CD platform currently offers managed Maven proxy. Potential product angle, but needs leadership input.     |

---

## References

- Slack incident thread: https://octopusdeploy.slack.com/archives/C085U3TMX1R/p1778587990772519
- Linear CF-1829 (proxy effort): https://linear.app/octopus/issue/CF-1829
- Linear CF-1843 (impact radius): https://linear.app/octopus/issue/CF-1843
- Sonatype blog (rate limiting): https://www.sonatype.com/blog/maven-central-and-the-tragedy-of-the-commons
- Sonatype blog (org-level limiting): https://www.sonatype.com/blog/beyond-ips-addressing-organizational-overconsumption-in-maven-central
- Status page incident: https://status.codefresh.io/incidents/hbxznfsss1md
- Codefresh platform IPs: https://codefresh.io/docs/docs/administration/platform-ip-addresses/
