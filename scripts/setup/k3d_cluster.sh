
cluster_name="scale-test"
agents=12
servers=3

k3d cluster stop "$cluster_name"
k3d cluster delete "$cluster_name"
k3d cluster create "$cluster_name" --agents $agents --servers $servers

