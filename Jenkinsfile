pipeline {

    // Run pipeline on any available Jenkins agent
    agent any

    // ─────────────────────────────────────────────────────────────
    // OPTIONS
    // ─────────────────────────────────────────────────────────────
    options {
        buildDiscarder(logRotator(numToKeepStr: '5'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }

    // ─────────────────────────────────────────────────────────────
    // ENVIRONMENT VARIABLES
    // ─────────────────────────────────────────────────────────────
    environment {

        APP_NAME      = 'foodfrenzy'
        IMAGE_NAME    = 'foodfrenzy'
        IMAGE_TAG     = "${BUILD_NUMBER}"
        K8S_NAMESPACE = 'foodfrenzy'

        EMAIL_TO      = 'bhuvan.abc.b12.reports@gmail.com'

        // Optional
        SLACK_CHANNEL = '#ci-notifications'
    }

    // ─────────────────────────────────────────────────────────────
    // STAGES
    // ─────────────────────────────────────────────────────────────
    stages {

        // =========================================================
        // STAGE 1 — CHECKOUT
        // =========================================================
        stage('Checkout') {

            steps {

                echo "=== Cleaning Workspace ==="

                cleanWs()

                echo "=== Cloning Repository ==="

                git(
                    branch: 'master',
                    url: 'https://github.com/bhuvan-aradhya-l/FoodFrenzy.git'
                )

                echo "Checked out commit: ${env.GIT_COMMIT?.take(7)}"
            }
        }

        // =========================================================
        // STAGE 2 — MAVEN BUILD INSIDE DOCKER CONTAINER
        // =========================================================
        stage('Maven Build') {

            agent {
                docker {

                    image 'maven:3.9-eclipse-temurin-17'

                    // Required so Docker container can run
                    reuseNode true

                    // Maven dependency cache
                    args '-v /root/.m2:/root/.m2'
                }
            }

            steps {

                sh '''
                    echo "=== Maven Build Started ==="

                    mvn clean package -DskipTests -B

                    echo "=== Maven Build Completed ==="

                    ls -lh target/*.jar
                '''
            }

            post {

                success {

                    echo "=== Stashing Build Artifacts ==="

                    stash(
                        name: 'app-artifacts',
                        includes: 'target/*.jar,Dockerfile,k8s/*.yaml'
                    )
                }
            }
        }

        // =========================================================
        // STAGE 3 — DOCKER BUILD INTO MINIKUBE
        // =========================================================
        stage('Docker Build') {

            steps {

                unstash 'app-artifacts'

                sh '''
                    echo "=== Configuring Minikube Docker Environment ==="

                    eval $(minikube -p minikube docker-env)

                    echo "=== Docker Environment Configured ==="

                    docker version

                    echo "=== Building Docker Image ==="

                    docker build \
                      -t ${IMAGE_NAME}:${IMAGE_TAG} \
                      -t ${IMAGE_NAME}:latest \
                      .

                    echo "=== Docker Image Built Successfully ==="

                    docker images | grep ${IMAGE_NAME}
                '''
            }
        }

        // =========================================================
        // STAGE 4 — DEPLOY TO KUBERNETES
        // =========================================================
        stage('Deploy to Kubernetes') {

            steps {

                sh '''
                    echo "=== Verifying Kubernetes Access ==="

                    kubectl get nodes

                    echo "=== Creating Namespace If Not Exists ==="

                    kubectl create namespace ${K8S_NAMESPACE} \
                      --dry-run=client -o yaml | kubectl apply -f -

                    echo "=== Deploying MySQL ==="

                    kubectl apply -f k8s/mysql-deployment.yaml \
                      -n ${K8S_NAMESPACE}

                    echo "=== Waiting For MySQL Pod ==="

                    kubectl wait \
                      --for=condition=ready pod \
                      -l app=mysql \
                      -n ${K8S_NAMESPACE} \
                      --timeout=180s

                    echo "=== Deploying FoodFrenzy Application ==="

                    kubectl apply -f k8s/foodfrenzy-deployment.yaml \
                      -n ${K8S_NAMESPACE}

                    echo "=== Updating Deployment Image ==="

                    kubectl set image deployment/foodfrenzy \
                      foodfrenzy=${IMAGE_NAME}:${IMAGE_TAG} \
                      -n ${K8S_NAMESPACE}

                    echo "=== Waiting For Rollout Completion ==="

                    kubectl rollout status deployment/foodfrenzy \
                      -n ${K8S_NAMESPACE} \
                      --timeout=180s

                    echo "=== Current Pods ==="

                    kubectl get pods -n ${K8S_NAMESPACE}

                    echo "=== Current Services ==="

                    kubectl get svc -n ${K8S_NAMESPACE}
                '''

                script {

                    env.APP_URL = sh(
                        script: """
                            minikube service foodfrenzy-service \
                            -n ${K8S_NAMESPACE} \
                            --url
                        """,
                        returnStdout: true
                    ).trim()

                    echo "Application URL: ${env.APP_URL}"
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // POST ACTIONS
    // ─────────────────────────────────────────────────────────────
    post {

        success {

            echo "=== PIPELINE SUCCEEDED ==="

            echo "Application URL: ${env.APP_URL}"

            // Uncomment after configuring Slack correctly

            /*
            slackSend(
                channel: env.SLACK_CHANNEL,
                color: 'good',
                tokenCredentialId: 'slack-token',
                message: ":white_check_mark: FoodFrenzy Build #${BUILD_NUMBER} SUCCEEDED\\n" +
                         "URL: ${env.APP_URL}"
            )
            */

            // Uncomment after configuring SMTP correctly

            /*
            emailext(
                subject: "[SUCCESS] FoodFrenzy Build #${BUILD_NUMBER}",
                to: env.EMAIL_TO,
                mimeType: 'text/html',
                body: """
                    <h2 style='color:green'>
                        FoodFrenzy Deployment Successful
                    </h2>

                    <p>
                        <b>Build Number:</b> #${BUILD_NUMBER}
                    </p>

                    <p>
                        <b>Application URL:</b>
                        ${env.APP_URL}
                    </p>

                    <p>
                        <a href='${BUILD_URL}'>
                            Open Jenkins Build
                        </a>
                    </p>
                """
            )
            */
        }

        failure {

            echo "=== PIPELINE FAILED ==="

            // Uncomment later

            /*
            slackSend(
                channel: env.SLACK_CHANNEL,
                color: 'danger',
                tokenCredentialId: 'slack-token',
                message: ":x: FoodFrenzy Build #${BUILD_NUMBER} FAILED\\n" +
                         "Console: ${BUILD_URL}console"
            )
            */
        }

        always {

            echo "=== Cleaning Workspace ==="

            cleanWs()
        }
    }
}
