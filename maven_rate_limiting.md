# How to Overcome Maven Central Rate Limiting in Codefresh Pipelines

> **Why you're seeing this:** Codefresh SaaS pipelines share a single egress IP. Maven Central
> (operated by Sonatype) rate-limits traffic per IP, and the combined volume from all customers
> running on shared runtimes can trigger that limit — causing your builds to fail with
> **HTTP 429 Too Many Requests**.
>
> The fix is straightforward: route your Maven dependency downloads through a **caching proxy**
> that sits between your pipeline and Maven Central. After the first download of each artifact,
> all subsequent requests are served from the cache — Maven Central never sees repeated traffic
> from your builds.

---

## Who Is Affected

This issue only affects pipelines running on **Codefresh shared SaaS runtimes**:

- `system/linux_paying_plan`
- `system/linux_non_paying_plan`
- `system/codefresh-enterprise`
- `system/plan/linux`

If your pipelines run on a **hybrid runner** (your own Kubernetes cluster), your builds already
use your own egress IP and are not affected by this issue.

---

## How a Caching Proxy Works

```
Without proxy (current):
  Pipeline → Maven Central   ← rate limited, repeated per build

With proxy:
  Pipeline → Proxy (cache hit) → done          ← most builds
  Pipeline → Proxy → Maven Central → cached    ← first download only
```

The only change required on your side is pointing Maven at the proxy URL. This is a
**one-line change** to `~/.m2/settings.xml` — no changes to your pipeline logic or
application code are needed in most cases.

---

## Option A: AWS CodeArtifact

**Best for:** teams running infrastructure on AWS.

AWS CodeArtifact is a fully managed artifact repository that can proxy Maven Central. After
the first download of any artifact, it caches a copy — subsequent requests never leave AWS.

> **Cost:** Free tier covers 2 GB storage + 100,000 requests/month. Beyond that:
> $0.05/GB storage, $0.05 per 10,000 requests. Typical cost after cache warm-up: **$10–30/month**.

### Step 1 — Create a CodeArtifact domain and repository

```bash
# Create a domain (one per AWS account is typical)
aws codeartifact create-domain --domain my-org

# Create a Maven repository with Maven Central as upstream
aws codeartifact create-repository \
  --domain my-org \
  --repository maven-proxy \
  --description "Maven Central caching proxy"

# Connect it to Maven Central
aws codeartifact associate-external-connection \
  --domain my-org \
  --repository maven-proxy \
  --external-connection public:maven-central
```

### Step 2 — Get your repository endpoint

```bash
aws codeartifact get-repository-endpoint \
  --domain my-org \
  --repository maven-proxy \
  --format maven \
  --query repositoryEndpoint \
  --output text
# Output: https://my-org-123456789012.d.codeartifact.us-east-1.amazonaws.com/maven/maven-proxy/
```

### Step 3 — Configure `~/.m2/settings.xml`

```xml
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
          https://maven.apache.org/xsd/settings-1.0.0.xsd">

  <servers>
    <server>
      <id>codeartifact</id>
      <username>aws</username>
      <!-- Token is injected at build time via environment variable -->
      <password>${env.CODEARTIFACT_AUTH_TOKEN}</password>
    </server>
  </servers>

  <mirrors>
    <mirror>
      <id>codeartifact</id>
      <name>CodeArtifact Maven Central Proxy</name>
      <url>https://my-org-123456789012.d.codeartifact.us-east-1.amazonaws.com/maven/maven-proxy/</url>
      <!-- Redirect all external Maven traffic through the proxy -->
      <mirrorOf>external:*</mirrorOf>
    </mirror>
  </mirrors>

</settings>
```

### Step 4 — Add a token refresh step to your Codefresh pipeline

CodeArtifact auth tokens expire every 12 hours, so you need to fetch a fresh one at the
start of each build. Add this as the first step in your pipeline:

```yaml
steps:
  get_codeartifact_token:
    title: Refresh CodeArtifact auth token
    image: amazon/aws-cli
    commands:
      - export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token \
          --domain my-org \
          --domain-owner 123456789012 \
          --query authorizationToken \
          --output text)
      # Write token into settings.xml for subsequent steps
      - mkdir -p ~/.m2
      - cp ci/settings.xml ~/.m2/settings.xml

  build:
    title: Maven build
    image: maven:3.9-eclipse-temurin-21
    commands:
      - mvn clean install
```

> **Tip:** Store `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_DEFAULT_REGION` as
> [Codefresh shared configuration secrets](https://codefresh.io/docs/docs/pipelines/shared-configuration/)
> rather than hardcoding them.

---

## Option B: Google Artifact Registry

**Best for:** teams running infrastructure on GCP.

GCP Artifact Registry supports **Remote Repositories** — a native Maven Central proxy built
into the platform. One command creates it. No per-request billing; you only pay for storage
and egress.

> **Cost:** Storage: $0.10/GB-month (first 0.5 GB free). Egress within GCP same region: free.
> Egress to non-GCP: $0.12–$0.23/GB. Typical cost after cache warm-up: **$5–20/month**.

### Step 1 — Create a Remote Repository

```bash
gcloud artifacts repositories create maven-proxy \
  --project=YOUR_PROJECT_ID \
  --repository-format=maven \
  --location=us-east1 \
  --description="Maven Central caching proxy" \
  --mode=remote-repository \
  --remote-mvn-repo=MAVEN-CENTRAL
```

### Step 2 — Get the repository URL

Your proxy URL follows this pattern:

```
https://LOCATION-maven.pkg.dev/PROJECT_ID/REPOSITORY_NAME/
# Example:
https://us-east1-maven.pkg.dev/my-project/maven-proxy/
```

### Step 3 — Add the Artifact Registry wagon to your project

GCP uses a Maven Wagon for authentication. Add this to your `pom.xml`:

```xml
<build>
  <extensions>
    <extension>
      <groupId>com.google.cloud.artifactregistry</groupId>
      <artifactId>artifactregistry-maven-wagon</artifactId>
      <version>2.2.5</version>
    </extension>
  </extensions>
</build>
```

Or create `.mvn/extensions.xml` at the project root (preferred for multi-module projects):

```xml
<extensions xmlns="http://maven.apache.org/EXTENSIONS/1.0.0"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:schemaLocation="http://maven.apache.org/EXTENSIONS/1.0.0
            https://maven.apache.org/xsd/core-extensions-1.0.0.xsd">
  <extension>
    <groupId>com.google.cloud.artifactregistry</groupId>
    <artifactId>artifactregistry-maven-wagon</artifactId>
    <version>2.2.5</version>
  </extension>
</extensions>
```

### Step 4 — Configure `~/.m2/settings.xml`

```xml
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
          https://maven.apache.org/xsd/settings-1.0.0.xsd">

  <mirrors>
    <mirror>
      <id>central</id>
      <name>GCP Artifact Registry — Maven Central Proxy</name>
      <url>artifactregistry://us-east1-maven.pkg.dev/my-project/maven-proxy</url>
      <mirrorOf>central</mirrorOf>
    </mirror>
  </mirrors>

</settings>
```

> **Note:** The `<id>` must be `central` to override Maven's built-in Central repository
> definition. The `artifactregistry://` scheme is handled by the wagon extension above.

### Step 5 — Authenticate in Codefresh pipeline

The wagon picks up [Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials)
automatically. In your Codefresh pipeline, set `GOOGLE_APPLICATION_CREDENTIALS` to a
service account key:

```yaml
steps:
  build:
    title: Maven build
    image: maven:3.9-eclipse-temurin-21
    environment:
      - GOOGLE_APPLICATION_CREDENTIALS=/tmp/sa-key.json
    commands:
      - echo "$GCP_SA_KEY" > /tmp/sa-key.json
      - mvn clean install
```

Store `GCP_SA_KEY` (the service account JSON key, base64-encoded or raw) as a
Codefresh secret variable.

---

## Option C: Azure Artifacts

**Best for:** teams already using Azure DevOps.

Azure Artifacts supports Maven feeds with upstream sources. When Maven Central is configured
as an upstream, Azure Artifacts automatically caches every package it fetches — subsequent
requests are served from your feed.

> **Cost:** First 2 GiB storage free. Additional storage ~$2/GiB. No per-request charges.
> For existing Azure DevOps users: effectively **$0–10/month**. Azure Artifacts snapshots
> are **not** supported via upstream sources.

### Step 1 — Create a feed with Maven Central upstream

1. In Azure DevOps, go to **Artifacts** → **Create Feed**
2. Name your feed (e.g. `maven-proxy`)
3. Check **"Include packages from common public sources"** — this enables Maven Central
   as an upstream automatically
4. Click **Create**

To add Maven Central to an existing feed manually:

1. Open your feed → gear icon → **Upstream sources**
2. Click **Add Upstream** → **Public source**
3. Select **Maven Central** (`https://repo.maven.apache.org/maven2/`)
4. Click **Save**

### Step 2 — Get your feed URL

Your feed URL follows this pattern:

```
https://pkgs.dev.azure.com/ORGANIZATION/PROJECT/_packaging/FEED_NAME/maven/v1
```

### Step 3 — Generate a Personal Access Token

In Azure DevOps: **User Settings** → **Personal Access Tokens** → **New Token**

Set scope: **Packaging → Read & write**

### Step 4 — Configure `~/.m2/settings.xml`

```xml
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
          https://maven.apache.org/xsd/settings-1.0.0.xsd">

  <servers>
    <server>
      <id>azure-artifacts</id>
      <username>AzureDevOps</username>
      <password>${env.AZURE_ARTIFACTS_PAT}</password>
    </server>
  </servers>

  <mirrors>
    <mirror>
      <id>azure-artifacts</id>
      <name>Azure Artifacts — Maven Central Proxy</name>
      <url>https://pkgs.dev.azure.com/MY_ORG/MY_PROJECT/_packaging/maven-proxy/maven/v1</url>
      <mirrorOf>external:*</mirrorOf>
    </mirror>
  </mirrors>

</settings>
```

### Step 5 — Set the PAT in your Codefresh pipeline

Store your PAT as a Codefresh secret variable named `AZURE_ARTIFACTS_PAT`. Maven picks it
up automatically via the `${env.AZURE_ARTIFACTS_PAT}` reference in `settings.xml`.

```yaml
steps:
  build:
    title: Maven build
    image: maven:3.9-eclipse-temurin-21
    commands:
      - mvn clean install
```

No extra token-refresh step needed — PATs are long-lived (up to 1 year).

---

## Option D: Self-Hosted Nexus Repository Manager

**Best for:** teams with an existing Kubernetes cluster (hybrid runner users) who want
full control, or teams that cannot use a cloud provider service.

Nexus Repository OSS is free and widely used. You deploy it once to your cluster;
it caches Maven Central artifacts automatically from that point on.

> **Cost:** Nexus OSS is free. Infrastructure cost depends on your setup — a minimal
> deployment (2 vCPU, 4 GB RAM, 100 GB storage) runs roughly **$60–120/month** on most
> cloud providers. A production-grade setup with SSD storage and egress is closer to
> **$200–500/month**.

### Step 1 — Deploy Nexus via Helm

```bash
helm repo add sonatype https://sonatype.github.io/helm3-charts/
helm repo update

helm install nexus sonatype/nexus-repository-manager \
  --namespace nexus \
  --create-namespace \
  --set nexus.env[0].name=INSTALL4J_ADD_VM_PARAMS \
  --set nexus.env[0].value="-Xms1024m -Xmx1024m"
```

### Step 2 — Configure a Maven proxy repository in Nexus

1. Open the Nexus UI (typically `http://nexus.your-domain.com`)
2. Log in (default credentials: admin / check `/nexus-data/admin.password`)
3. Go to **Settings** → **Repositories** → **Create repository**
4. Choose **maven2 (proxy)**
5. Set:
   - **Name:** `maven-central-proxy`
   - **Remote storage URL:** `https://repo.maven.apache.org/maven2/`
   - **Blob store:** default
6. Click **Create repository**

Your proxy URL will be:

```
http://nexus.your-domain.com/repository/maven-central-proxy/
```

### Step 3 — Configure `~/.m2/settings.xml`

If Nexus is open (no auth required for read), you only need the mirror entry:

```xml
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
          https://maven.apache.org/xsd/settings-1.0.0.xsd">

  <mirrors>
    <mirror>
      <id>nexus</id>
      <name>Nexus Maven Central Proxy</name>
      <url>http://nexus.your-domain.com/repository/maven-central-proxy/</url>
      <mirrorOf>external:*</mirrorOf>
    </mirror>
  </mirrors>

</settings>
```

If Nexus requires authentication, add a `<servers>` block:

```xml
<servers>
  <server>
    <id>nexus</id>
    <username>${env.NEXUS_USER}</username>
    <password>${env.NEXUS_PASSWORD}</password>
  </server>
</servers>
```

### Step 4 — No extra pipeline steps needed

Once `settings.xml` is in place (either committed to your repo or provided via a Codefresh
shared configuration), your builds just work:

```yaml
steps:
  build:
    title: Maven build
    image: maven:3.9-eclipse-temurin-21
    commands:
      - mvn clean install
```

---

## Applying `settings.xml` in Codefresh — Three Approaches

Regardless of which proxy option you choose, you need Maven to use your custom `settings.xml`
inside the pipeline. Here are three ways to do it:

### 1. Commit `settings.xml` to your repository

Store it at `ci/settings.xml` (not at root, to avoid confusion with local dev settings),
then pass it explicitly to Maven:

```yaml
commands:
  - mvn clean install -s ci/settings.xml
```

### 2. Write it dynamically in the pipeline step

Useful when the proxy URL or credentials vary per environment:

```yaml
commands:
  - mkdir -p ~/.m2
  - |
    cat > ~/.m2/settings.xml <<EOF
    <settings>
      <mirrors>
        <mirror>
          <id>proxy</id>
          <url>${PROXY_URL}</url>
          <mirrorOf>external:*</mirrorOf>
        </mirror>
      </mirrors>
    </settings>
    EOF
  - mvn clean install
```

### 3. Use a Codefresh shared configuration

Store the `settings.xml` content as a
[shared configuration](https://codefresh.io/docs/docs/pipelines/shared-configuration/)
and mount it as an environment variable or file across pipelines in your account.

---

## Verifying the Proxy Works

Add `-X` (debug) or `-e` (errors) to your Maven command and look for lines like:

```
[DEBUG] Using mirror external:* (repo proxy) for central (https://repo.maven.apache.org/maven2/)
Downloading from proxy: https://your-proxy-url/org/apache/...
```

If you see your proxy URL instead of `repo.maven.apache.org`, the redirect is working.

To confirm caching is happening, run the same build twice. The second run should show
`Downloading` replaced with `Using cached artifact` or significantly faster download times.

---

## Choosing the Right Option

| Option                  | Best If You're On        | Monthly Cost   | Setup Time  | Snapshots |
|-------------------------|--------------------------|----------------|-------------|-----------|
| AWS CodeArtifact        | AWS                      | $0–30          | ~30 min     | ✅ Yes    |
| GCP Artifact Registry   | GCP                      | $5–20          | ~15 min     | ✅ Yes    |
| Azure Artifacts         | Azure DevOps             | $0–10          | ~20 min     | ❌ No     |
| Self-hosted Nexus OSS   | Own Kubernetes cluster   | ~$60–500 infra | ~2–4 hours  | ✅ Yes    |

---

## Still Blocked?

If your builds are currently returning 429 errors and you need an immediate unblock while
you set up a proxy, contact [Codefresh Support](https://support.codefresh.io). We can
liaise with Sonatype to temporarily whitelist our shared IP while you implement a
permanent solution.

Note that Maven Central also applies **per-organisation behavioural rate limits** independently
of the shared IP. If your pipelines are retrying aggressively on failure, reduce the retry
count to avoid triggering a personal block on top of the IP-level one.

---

## Further Reading

- [Maven Settings Reference](https://maven.apache.org/settings.html)
- [Maven Mirror Settings Guide](https://maven.apache.org/guides/mini/guide-mirror-settings.html)
- [AWS CodeArtifact — Use with mvn](https://docs.aws.amazon.com/codeartifact/latest/ug/maven-mvn.html)
- [GCP Artifact Registry — Remote Repositories](https://cloud.google.com/artifact-registry/docs/repositories/remote-overview)
- [Azure Artifacts — Use packages from Maven Central](https://learn.microsoft.com/en-us/azure/devops/artifacts/maven/upstream-sources)
- [Sonatype Nexus — Maven Repositories](https://help.sonatype.com/en/maven-repositories.html)
