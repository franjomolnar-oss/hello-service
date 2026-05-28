# Jenkins Deployment Setup

## Preduvjeti

### 1. Jenkins Plugins
Instaliraj ove plugine u Jenkins:
- **Pipeline** - Pipeline plugin
- **Docker** - Docker plugin
- **Kubernetes** - Kubernetes plugin
- **Credentials** - Credentials plugin
- **Git** - Git plugin
- **Slack** (opciono) - Slack Notification plugin

```bash
# Ili koristi docker image sa pluginima pre-instaliranim
docker run -d \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:latest
```

### 2. Credentials Setup

U Jenkins -> Manage Credentials dodaj:

#### a) Docker Registry Credentials
- **ID**: `docker-registry-credentials`
- **Type**: Username with password
- **Username**: Tvoj Docker username
- **Password**: Docker password/token

#### b) Docker Registry URL
- **ID**: `docker-registry-url`
- **Type**: Secret text
- **Value**: `docker.io` (ili tvoj private registry)

#### c) Kubernetes Config
- **ID**: `kubeconfig`
- **Type**: Secret file
- **File**: Tvoj kubeconfig file (`~/.kube/config`)

```bash
# Primjer kako dobiti kubeconfig:
kubectl config view --flatten > kubeconfig.yaml
```

### 3. Kubernetes Namespace i RBAC

```bash
# Kreiraj namespaces
kubectl create namespace staging
kubectl create namespace production

# Kreiraj service account za Jenkins
kubectl create serviceaccount jenkins -n staging
kubectl create serviceaccount jenkins -n production

# Kreiraj role i role binding
kubectl create role pod-reader \
  --verb=get,list,watch,create,update,patch,delete \
  --resource=pods,services,deployments,configmaps \
  -n staging

kubectl create rolebinding jenkins-pod-reader \
  --role=pod-reader \
  --serviceaccount=staging:jenkins \
  -n staging

# Ponovi za production
```

## Job Setup

### 1. Nova Pipeline Job

1. Jenkins Dashboard -> **New Item**
2. Unesi ime: `hello-service-deploy`
3. Odaberi: **Pipeline**
4. Klikni **OK**

### 2. Pipeline Configuration

U sekciji **Pipeline**:
- **Definition**: Pipeline script from SCM
- **SCM**: Git
- **Repository URL**: `https://github.com/franjo/hello-service.git`
- **Branch**: `*/main` (ili tvoja branch)
- **Script Path**: `Jenkinsfile`

Ili direktno kao Jenkinsfile:
- **Definition**: Pipeline script
- Kopira sadržaj iz Jenkinsfile-a

### 3. Build Triggers (opciono)

Za automatski deployment:
- ✅ **Poll SCM**: `H/5 * * * *` (svakih 5 minuta)
- Ili webhook sa GitHub/GitLab

## Pokretanje Joba

### Manualno:
```bash
# Jenkins CLI
java -jar jenkins-cli.jar -s http://localhost:8080 \
  build hello-service-deploy \
  -p ENVIRONMENT=staging \
  -p IMAGE_TAG=1.0.1
```

### Preko Jenkins UI:
1. Klikni na job: `hello-service-deploy`
2. Klikni **Build with Parameters**
3. Odaberi:
   - **ENVIRONMENT**: staging ili production
   - **IMAGE_TAG**: verzija (npr. 1.0.1)
4. Klikni **Build**

## Troubleshooting

### Docker push greškai
```bash
# Provjeri credentials
docker login

# Provjeri docker daemon
docker ps
```

### Kubernetes connection errors
```bash
# Provjeri kubeconfig
kubectl cluster-info

# Provjeri service account permissions
kubectl get rolebindings -n staging
```

### Helm deployment errors
```bash
# Provjeri helm chart validity
helm lint ./helm/hello-service

# Dry-run deployment
helm template hello-service ./helm/hello-service \
  --values ./helm/hello-service/values-staging.yaml
```

## Next Steps

1. **Dodaj Slack notifications** - za notifikacije na Slack kanal
2. **Dodaj SonarQube** - za code quality analysis
3. **Dodaj ArgoCD** - za GitOps deployment
4. **Dodaj monitoring** - Prometheus + Grafana
5. **Setup SSL/TLS** - za HTTPS
