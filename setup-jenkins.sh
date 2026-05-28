#!/bin/bash

# Jenkins Job Setup Script
# Korištenje: ./setup-jenkins.sh

set -e

echo "🚀 Starting Jenkins Job Setup..."
echo ""

# Korak 1: Docker Registry Credentials
echo "📝 Step 1: Docker Registry Credentials"
read -p "Enter Docker Registry URL (default: docker.io): " REGISTRY
REGISTRY=${REGISTRY:-docker.io}
read -p "Enter Docker Username: " DOCKER_USER
read -sp "Enter Docker Password/Token: " DOCKER_PASS
echo ""

# Korak 2: Kubernetes Config
echo "📝 Step 2: Kubernetes Configuration"
read -p "Enter path to kubeconfig file (default: ~/.kube/config): " KUBECONFIG_PATH
KUBECONFIG_PATH=${KUBECONFIG_PATH:-$HOME/.kube/config}

if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo "❌ Kubeconfig file not found at $KUBECONFIG_PATH"
    exit 1
fi

# Korak 3: Jenkins URL
echo "📝 Step 3: Jenkins Configuration"
read -p "Enter Jenkins URL (default: http://localhost:8080): " JENKINS_URL
JENKINS_URL=${JENKINS_URL:-http://localhost:8080}
read -sp "Enter Jenkins API Token: " JENKINS_TOKEN
echo ""

# Korak 4: Kreiradi Kubernetes namespaces i RBAC
echo "🔧 Setting up Kubernetes namespaces and RBAC..."

for NAMESPACE in staging production; do
    echo "  Creating namespace: $NAMESPACE"
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    echo "  Creating service account: jenkins in $NAMESPACE"
    kubectl create serviceaccount jenkins -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    echo "  Creating role and role binding in $NAMESPACE"
    kubectl create role pod-reader \
      --verb=get,list,watch,create,update,patch,delete \
      --resource=pods,services,deployments,configmaps,statefulsets \
      -n $NAMESPACE \
      --dry-run=client -o yaml | kubectl apply -f -
    
    kubectl create rolebinding jenkins-pod-reader \
      --role=pod-reader \
      --serviceaccount=$NAMESPACE:jenkins \
      -n $NAMESPACE \
      --dry-run=client -o yaml | kubectl apply -f -
done

echo "✅ Kubernetes setup complete"
echo ""

# Korak 5: Kreiradi Jenkins credentials koristeći Jenkins API
echo "🔐 Creating Jenkins Credentials..."

# Flatten kubeconfig
KUBECONFIG_CONTENT=$(kubectl config view --flatten)

# Create Credentials JSON
DOCKER_CREDS=$(cat <<EOF
{
  "credentials": {
    "": {
      "description": "Docker Registry Credentials",
      "password": "$DOCKER_PASS",
      "scope": "GLOBAL",
      "username": "$DOCKER_USER",
      "\$class": "com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl"
    }
  }
}
EOF
)

# Kreiraj credentials uz Jenkins CLI ili API
echo "⚠️  Trebate ručno dodati credentials u Jenkins:"
echo ""
echo "1. Idi na: $JENKINS_URL/credentials/store/system/domain/_/"
echo "2. Klikni 'Add Credentials'"
echo ""
echo "3. Za Docker Registry:"
echo "   - Kind: Username with password"
echo "   - ID: docker-registry-credentials"
echo "   - Username: $DOCKER_USER"
echo "   - Password: [unesite password]"
echo ""
echo "4. Za Docker Registry URL:"
echo "   - Kind: Secret text"
echo "   - ID: docker-registry-url"
echo "   - Secret: $REGISTRY"
echo ""
echo "5. Za Kubeconfig:"
echo "   - Kind: Secret file"
echo "   - ID: kubeconfig"
echo "   - File: [upload $KUBECONFIG_PATH]"
echo ""

# Korak 6: Kreiraj Jenkins Job (XML config)
echo "🔧 Creating Jenkins Job Configuration..."

JOB_NAME="hello-service-deploy"
JOB_CONFIG=$(cat <<'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<org.jenkinsci.plugins.workflow.job.WorkflowJob plugin="workflow-job@1330.v55a514b_eb_b_5c">
  <actions/>
  <description>Automated deployment pipeline for hello-service to Kubernetes</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.GerritTriggerProperty plugin="gerrit-trigger@2.27.11">
      <skipVote>
        <onSuccessful>false</onSuccessful>
        <onFailed>false</onFailed>
      </skipVote>
      <silentStartMode>false</silentStartMode>
      <notificationLevel/>
      <notificationRecipientType/>
      <silentStartMode>false</silentStartMode>
      <silentPerformMergeOnSuccessfulVote>false</silentPerformMergeOnSuccessfulVote>
    </com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.GerritTriggerProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2738.v47cac936a_115">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@4.10.3">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>https://github.com/franjo/hello-service.git</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="java.util.LinkedList"/>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</org.jenkinsci.plugins.workflow.job.WorkflowJob>
EOF
)

echo "✅ Job configuration created"
echo ""
echo "📦 To create the job via Jenkins CLI:"
echo "  java -jar jenkins-cli.jar -s $JENKINS_URL -auth user:token create-job $JOB_NAME < job-config.xml"
echo ""

# Korak 7: Ispis summary-ja
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "📋 Summary:"
echo "  - Kubernetes Namespaces: staging, production"
echo "  - Service Account: jenkins (in both namespaces)"
echo "  - Docker Registry: $REGISTRY"
echo "  - Jenkins URL: $JENKINS_URL"
echo "  - Kubeconfig: $KUBECONFIG_PATH"
echo ""
echo "🔗 Next Steps:"
echo "  1. Complete credential setup in Jenkins UI"
echo "  2. Create new Pipeline job: hello-service-deploy"
echo "  3. Point to this repository and Jenkinsfile"
echo "  4. Run: Build with Parameters"
echo ""
echo "📖 For more details, see: JENKINS_SETUP.md"
echo ""
