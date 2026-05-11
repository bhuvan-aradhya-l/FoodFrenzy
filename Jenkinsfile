pipeline {

  // Run pipeline on any available Jenkins agent
  agent any

  // ── Global Pipeline Options ─────────────────────────────────────
  options {
    buildDiscarder(logRotator(numToKeepStr: '5'))
    timeout(time: 45, unit: 'MINUTES')
    timestamps()
  }

  // ── Environment Variables ──────────────────────────────────────
  environment {

    // Application
    APP_NAME      = 'foodfrenzy'
    IMAGE_NAME    = 'foodfrenzy'
    IMAGE_TAG     = "${BUILD_NUMBER}"

    // Kubernetes
    K8S_NAMESPACE = 'foodfrenzy'

    // Notifications
    EMAIL_TO      = 'bhuvan.abc.b12.reports@gmail.com'
    SLACK_CHANNEL = 'C0A1H9UDPUG'
  }

  stages {

    // ──────────────────────────────────────────────────────────────
    // STAGE 1 — Checkout Source Code
    // ──────────────────────────────────────────────────────────────
    stage('Checkout') {

      steps {

        echo "=== Cleaning Workspace ==="

        cleanWs()

        echo "=== Cloning GitHub Repository ==="

        git(
          branch: 'master',
          url: 'https://github.com/bhuvan-aradhya-l/FoodFrenzy.git'
        )

        sh '''
          echo "=== Current Commit ==="
          git log --oneline -1
        '''
      }
    }

    // ──────────────────────────────────────────────────────────────
    // STAGE 2 — Build Java Application
    // Uses Dockerized Maven
    // ──────────────────────────────────────────────────────────────
    stage('Maven Build') {

      agent {
        docker {
          image 'maven:3.9-eclipse-temurin-17'
          reuseNode true
          args '-v /root/.m2:/root/.m2'
        }
      }

      steps {

        sh '''
          echo "=== Maven Version ==="
          mvn -version

          echo "=== Starting Maven Build ==="

          mvn clean package -DskipTests -B

          echo "=== Build Successful ==="

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

    // ──────────────────────────────────────────────────────────────
    // STAGE 3 — Build Docker Image Inside Minikube
    // ──────────────────────────────────────────────────────────────
    stage('Docker Build') {

      steps {

        unstash 'app-artifacts'

        sh '''
          echo "=== Verifying Minikube Status ==="

          minikube status

          echo "=== Connecting Docker CLI To Minikube Docker Daemon ==="

          eval $(minikube docker-env)

          echo "=== Building Docker Image ==="

          docker build \
            -t ${IMAGE_NAME}:${IMAGE_TAG} \
            -t ${IMAGE_NAME}:latest .

          echo "=== Docker Images ==="

          docker images | grep ${IMAGE_NAME}
        '''
      }
    }

    // ──────────────────────────────────────────────────────────────
    // STAGE 4 — Deploy MySQL + Application To Kubernetes
    // ──────────────────────────────────────────────────────────────
    stage('Deploy to Kubernetes') {

      steps {

        sh '''
          echo "=== Verifying Kubernetes Cluster Access ==="

          kubectl get nodes

          echo "=== Creating Namespace If Missing ==="

          kubectl create namespace ${K8S_NAMESPACE} \
            --dry-run=client -o yaml | kubectl apply -f -

          echo "=== Creating MySQL Secret ==="

          kubectl create secret generic mysql-secret \
            --from-literal=root-password=root123 \
            --from-literal=username=fooduser \
            --from-literal=password=foodpass \
            -n ${K8S_NAMESPACE} \
            --dry-run=client -o yaml | kubectl apply -f -

          echo "=== Deploying MySQL ==="

          kubectl apply -f k8s/mysql-deployment.yaml \
            -n ${K8S_NAMESPACE}

          echo "=== Waiting For MySQL Pod Creation ==="

          sleep 15

          echo "=== MySQL Pod Status ==="

          kubectl get pods -n ${K8S_NAMESPACE}

          echo "=== Waiting For MySQL Rollout ==="

          kubectl rollout status deployment/mysql \
            -n ${K8S_NAMESPACE} \
            --timeout=180s

          echo "=== Deploying FoodFrenzy Application ==="

          kubectl apply -f k8s/foodfrenzy-deployment.yaml \
            -n ${K8S_NAMESPACE}

          echo "=== Updating Deployment Image ==="

          kubectl set image deployment/foodfrenzy \
            foodfrenzy=${IMAGE_NAME}:${IMAGE_TAG} \
            -n ${K8S_NAMESPACE}

          echo "=== Waiting For FoodFrenzy Rollout ==="

          kubectl rollout status deployment/foodfrenzy \
            -n ${K8S_NAMESPACE} \
            --timeout=300s

          echo "=== Final Pod Status ==="

          kubectl get pods -n ${K8S_NAMESPACE}

          echo "=== Service Status ==="

          kubectl get svc -n ${K8S_NAMESPACE}
        '''

        // ── Fetch Application URL ───────────────────────────────
        script {

          echo "=== Fetching FoodFrenzy Application URL ==="

          env.APP_URL = sh(
            script: """
              minikube service foodfrenzy-service \
              -n ${K8S_NAMESPACE} \
              --url
            """,
            returnStdout: true
          ).trim()

          echo "=================================================="
          echo "FoodFrenzy Application URL:"
          echo "${env.APP_URL}"
          echo "=================================================="
        }
      }
    }

  } // END STAGES

  // ──────────────────────────────────────────────────────────────
  // POST BUILD ACTIONS
  // ──────────────────────────────────────────────────────────────
  post {

    success {

      echo "=== PIPELINE SUCCEEDED ==="

      echo "Application URL: ${env.APP_URL}"

      // ── Slack Notification ─────────────────────────────────
      slackSend(
        channel: env.SLACK_CHANNEL,
        color: 'good',
        tokenCredentialId: 'slack-token-k8s',
        message:
          ":white_check_mark: FoodFrenzy Build #${BUILD_NUMBER} SUCCESS\n" +
          "Application URL: ${env.APP_URL}\n" +
          "Jenkins Build: ${BUILD_URL}"
      )

      // ── Email Notification ─────────────────────────────────
      emailext(
        to: env.EMAIL_TO,
        subject: "[SUCCESS] FoodFrenzy Build #${BUILD_NUMBER}",
        mimeType: 'text/html',
        body: """
          <h2 style="color:green;">
            FoodFrenzy Deployment Successful
          </h2>

          <p>
            <b>Build Number:</b> ${BUILD_NUMBER}
          </p>

          <p>
            <b>Application URL:</b><br>
            <a href="${env.APP_URL}">
              ${env.APP_URL}
            </a>
          </p>

          <p>
            <a href="${BUILD_URL}">
              View Jenkins Build
            </a>
          </p>
        """
      )
    }

    failure {

      echo "=== PIPELINE FAILED ==="

      // ── Slack Notification ─────────────────────────────────
      slackSend(
        channel: env.SLACK_CHANNEL,
        color: 'danger',
        tokenCredentialId: 'slack-token-k8s',
        message:
          ":x: FoodFrenzy Build #${BUILD_NUMBER} FAILED\n" +
          "Console Log: ${BUILD_URL}console"
      )

      // ── Email Notification ─────────────────────────────────
      emailext(
        to: env.EMAIL_TO,
        subject: "[FAILED] FoodFrenzy Build #${BUILD_NUMBER}",
        mimeType: 'text/html',
        body: """
          <h2 style="color:red;">
            FoodFrenzy Deployment Failed
          </h2>

          <p>
            <b>Build Number:</b> ${BUILD_NUMBER}
          </p>

          <p>
            <a href="${BUILD_URL}console">
              View Console Log
            </a>
          </p>
        """
      )
    }

    always {

      echo "=== Cleaning Workspace ==="

      cleanWs()
    }
  }
}
