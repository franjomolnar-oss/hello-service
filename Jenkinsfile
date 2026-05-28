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
        REGISTRY = "docker.io"
        DOCKER_IMAGE = "hello-service"
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
            when {
                expression { env.BUILD_DOCKER_IMAGE == 'true' }
            }
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
            when {
                expression { env.REGISTRY_USER != null && env.REGISTRY_PASSWORD != null }
            }
            steps {
                script {
                    echo "📤 Pushing image to registry..."
                    sh '''
                        echo ${REGISTRY_PASSWORD} | docker login -u ${REGISTRY_USER} --password-stdin ${REGISTRY}
                        docker push ${DOCKER_IMAGE}:${IMAGE_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                        docker logout ${REGISTRY}
                    '''
                }
            }
        }

        stage('Register ArgoCD Application') {
            steps {
                script {
                    echo "📋 Registering ArgoCD application for ${ENVIRONMENT}..."
                    sh '''
                        APP_NAME="hello-service-${ENVIRONMENT}"
                        ARGOCD_SERVER=${ARGOCD_SERVER:-localhost:6443}
                        
                        # Create ArgoCD application if it doesn't exist
                        kubectl apply -f ./argocd/app-${ENVIRONMENT}.yaml || true
                        
                        echo "✅ ArgoCD application registered: $APP_NAME"
                    '''
                }
            }
        }

        stage('Deploy with ArgoCD') {
            steps {
                script {
                    echo "🚀 Deploying to ${ENVIRONMENT} via ArgoCD..."
                    sh '''
                        APP_NAME="hello-service-${ENVIRONMENT}"
                        
                        # Update the image tag in ArgoCD application
                        kubectl patch application $APP_NAME -n argocd \
                            --type json -p='[{"op": "replace", "path": "/spec/source/helm/parameters/0/value", "value":"'${IMAGE_TAG}'"}]' || true
                        
                        # Trigger ArgoCD sync
                        argocd app sync $APP_NAME --grpc-web || \
                        kubectl patch application $APP_NAME -n argocd -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' || true
                        
                        echo "✅ Deployment triggered via ArgoCD"
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
