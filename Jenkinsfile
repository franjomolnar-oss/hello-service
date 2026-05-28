pipeline {
    agent any

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['staging', 'production'],
            description: 'Target environment for deployment'
        )
        string(
            name: 'IMAGE_TAG',
            defaultValue: '1.0.0',
            description: 'Docker image tag'
        )
    }

    environment {
        REGISTRY = credentials('docker-registry-url')
        REGISTRY_CREDENTIALS = credentials('docker-registry-credentials')
        DOCKER_IMAGE = "${REGISTRY}/hello-service"
        KUBECONFIG = "${HOME}/.kube/config"
        HELM_CHART_PATH = './helm/hello-service'
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "🔄 Checking out code..."
                    checkout scm
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "🔨 Building Docker image..."
                    sh '''
                        docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} .
                        docker tag ${DOCKER_IMAGE}:${IMAGE_TAG} ${DOCKER_IMAGE}:latest
                    '''
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    echo "📤 Pushing image to registry..."
                    sh '''
                        echo ${REGISTRY_CREDENTIALS_PSW} | docker login -u ${REGISTRY_CREDENTIALS_USR} --password-stdin ${REGISTRY}
                        docker push ${DOCKER_IMAGE}:${IMAGE_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                        docker logout ${REGISTRY}
                    '''
                }
            }
        }

        stage('Deploy with Helm') {
            steps {
                script {
                    echo "🚀 Deploying to ${ENVIRONMENT}..."
                    sh '''
                        helm repo update || true
                        
                        helm upgrade --install hello-service ${HELM_CHART_PATH} \
                            --namespace ${ENVIRONMENT} \
                            --create-namespace \
                            --values ${HELM_CHART_PATH}/values-${ENVIRONMENT}.yaml \
                            --set image.tag=${IMAGE_TAG} \
                            --set image.repository=${DOCKER_IMAGE} \
                            --wait \
                            --timeout 5m
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    echo "✅ Verifying deployment..."
                    sh '''
                        kubectl rollout status deployment/hello-service \
                            -n ${ENVIRONMENT} \
                            --timeout=3m
                        
                        echo "Pod status:"
                        kubectl get pods -n ${ENVIRONMENT} -l app=hello-service
                    '''
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    echo "🏥 Running health checks..."
                    sh '''
                        POD_NAME=$(kubectl get pods -n ${ENVIRONMENT} -l app=hello-service \
                            -o jsonpath='{.items[0].metadata.name}')
                        
                        echo "Testing health endpoint on pod: $POD_NAME"
                        kubectl port-forward -n ${ENVIRONMENT} $POD_NAME 3000:3000 &
                        sleep 2
                        
                        curl -f http://localhost:3000/health || exit 1
                        echo "✅ Health check passed"
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                echo "🧹 Cleaning up..."
            }
        }
        success {
            echo "✅ Deployment successful!"
            // Dodaj notification (Slack, email, itd.)
            // slackSend(color: 'good', message: "hello-service deployed to ${ENVIRONMENT}")
        }
        failure {
            echo "❌ Deployment failed!"
            // slackSend(color: 'danger', message: "hello-service deployment to ${ENVIRONMENT} failed")
        }
    }
}
