pipeline {
 
  // No default agent. Each stage picks its own.
  agent none
 
  // ── Build Options ────────────────────────────────────────────
  options {
    buildDiscarder(logRotator(numToKeepStr: '5'))
    timeout(time: 30, unit: 'MINUTES')
    timestamps()
  }
 
  // ── Environment Variables ─────────────────────────────────────
  environment {
    APP_NAME      = 'foodfrenzy'
    IMAGE_NAME    = 'foodfrenzy'
    IMAGE_TAG     = "${BUILD_NUMBER}"
    K8S_NAMESPACE = 'foodfrenzy'
    // Replace with your real email and Slack channel
    EMAIL_TO      = 'your-email@example.com'
    SLACK_CHANNEL = '#ci-notifications'
  }
 
  stages {
 
    // ── STAGE 1: Checkout ─────────────────────────────────────
    // Runs on the Jenkins Linux agent.
    // Checks out the FoodFrenzy source code from GitHub.
    stage('Checkout') {
      agent { label 'linux docker agent' }
      steps {
        // Clean the workspace before checking out
        cleanWs()
        git branch: 'master',
            url: 'https://github.com/bhuvan-aradhya-l/FoodFrenzy.git'
        echo "Checked out commit: ${env.GIT_COMMIT?.take(7)}"
      }
    }
 
    // ── STAGE 2: Build (Docker Container as SLAVE) ────────────
    // This stage uses a Docker container AS the build environment.
    // Jenkins pulls the maven:3.9-eclipse-temurin-17 image,
    // mounts the workspace into it, and runs mvn inside it.
    // You do NOT need Maven installed on the Jenkins agent.
    stage('Maven Build') {
      agent {
        docker {
          image 'maven:3.9-eclipse-temurin-17'
          label 'linux docker agent'
          // Cache the local Maven repo between builds to save download time
          args '-v /root/.m2:/root/.m2'
        }
      }
      steps {
        sh '''
          echo "=== Building FoodFrenzy with Maven ==="
          mvn clean package -DskipTests -B
          echo "=== Build complete. JAR file: ==="
          ls -lh target/*.jar
        '''
      }
      // Stash the JAR so the next stage (different agent) can use it
      post {
        success {
          stash name: 'app-jar', includes: 'target/*.jar, Dockerfile'
        }
      }
    }
 
    // ── STAGE 3: Docker Build (Docker as AGENT) ───────────────
    // Here 'Docker as agent' means we run docker CLI commands
    // directly on the Jenkins agent (not inside a Docker container).
    // We build the image INTO Minikube's Docker daemon so Kubernetes
    // can use it without any registry.
    stage('Docker Build') {
      agent { label 'linux docker agent' }
      steps {
        // Retrieve the JAR built in the previous stage
        unstash 'app-jar'
        sh '''
          echo "=== Building Docker image into Minikube ==="
 
          # Point Docker CLI to Minikube's internal Docker daemon.
          # Any image built here is instantly usable by Kubernetes.
          eval $(minikube docker-env)
 
          # Build the image with both a build number tag and 'latest'
          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest .
 
          echo "=== Image built successfully ==="
          docker images | grep ${IMAGE_NAME}
        '''
      }
    }
 
    // ── STAGE 4: Deploy to Kubernetes ─────────────────────────
    // Uses the Kubernetes plugin to spin up a temporary pod
    // with kubectl inside Minikube. Applies the K8s manifests,
    // waits for the deployment to be healthy, then the pod
    // is automatically destroyed by Jenkins.
    stage('Deploy to Kubernetes') {
      agent {
        kubernetes {
          cloud 'minikube'
          label 'k8s-deploy-pod'
          namespace 'foodfrenzy'
          yaml '''
            apiVersion: v1
            kind: Pod
            spec:
              serviceAccountName: jenkins
              containers:
                - name: jnlp
                  image: jenkins/inbound-agent:latest
                - name: kubectl
                  image: bitnami/kubectl:latest
                  command: ["sleep", "infinity"]
          '''
          defaultContainer 'kubectl'
        }
      }
      steps {
        // Retrieve source code (manifests are in k8s/ folder)
        checkout scm
        sh '''
          echo "=== Deploying to Kubernetes ==="
 
          # Create namespace if it does not exist yet
          kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
 
          # Deploy MySQL first
          kubectl apply -f k8s/mysql-deployment.yaml
 
          # Wait for MySQL to be ready (up to 3 minutes)
          echo "Waiting for MySQL to be ready..."
          kubectl wait --for=condition=ready pod -l app=mysql \
            -n ${K8S_NAMESPACE} --timeout=180s
 
          # Deploy FoodFrenzy application
          kubectl apply -f k8s/foodfrenzy-deployment.yaml
 
          # Update the image tag to match this build
          kubectl set image deployment/foodfrenzy \
            foodfrenzy=${IMAGE_NAME}:${IMAGE_TAG} \
            -n ${K8S_NAMESPACE}
 
          # Wait for rollout to complete (up to 3 minutes)
          echo "Waiting for FoodFrenzy rollout..."
          kubectl rollout status deployment/foodfrenzy \
            -n ${K8S_NAMESPACE} --timeout=180s
 
          echo "=== Deployment complete ==="
          kubectl get pods -n ${K8S_NAMESPACE}
        '''
        // Save the access URL for display in the notification
        script {
          env.APP_URL = sh(
            script: "minikube service foodfrenzy-service -n ${K8S_NAMESPACE} --url 2>/dev/null || echo 'Run: minikube service foodfrenzy-service -n foodfrenzy --url'",
            returnStdout: true
          ).trim()
        }
      }
    }
 
  } // end stages
 
  // ── Post-Build Notifications ──────────────────────────────────
  post {
    success {
      // Slack — green message on success
      slackSend(
        channel: env.SLACK_CHANNEL,
        color: 'good',
        tokenCredentialId: 'slack-token',
        message: ":white_check_mark: *FoodFrenzy Build #${BUILD_NUMBER} SUCCEEDED*\n" +
                 "Branch: master | Commit: ${env.GIT_COMMIT?.take(7)}\n" +
                 "Access URL: ${env.APP_URL}\n" +
                 "Jenkins: ${BUILD_URL}"
      )
      // Email — on success
      emailext(
        subject: "[SUCCESS] FoodFrenzy Build #${BUILD_NUMBER}",
        to: env.EMAIL_TO,
        mimeType: 'text/html',
        body: """
          <h2 style='color:green'>FoodFrenzy Deployment Succeeded</h2>
          <p><b>Build:</b> #${BUILD_NUMBER}</p>
          <p><b>Duration:</b> ${currentBuild.durationString}</p>
          <p><b>Access the app at:</b> ${env.APP_URL}</p>
          <p><a href='${BUILD_URL}'>View Jenkins Build</a></p>
        """
      )
    }
    failure {
      // Slack — red message on failure
      slackSend(
        channel: env.SLACK_CHANNEL,
        color: 'danger',
        tokenCredentialId: 'slack-token',
        message: ":x: *FoodFrenzy Build #${BUILD_NUMBER} FAILED*\n" +
                 "Check the console log: ${BUILD_URL}console"
      )
      // Email — on failure
      emailext(
        subject: "[FAILED] FoodFrenzy Build #${BUILD_NUMBER}",
        to: env.EMAIL_TO,
        mimeType: 'text/html',
        body: """
          <h2 style='color:red'>FoodFrenzy Build Failed</h2>
          <p><b>Build:</b> #${BUILD_NUMBER}</p>
          <p><a href='${BUILD_URL}console'>View Console Log</a></p>
        """
      )
    }
    always {
      cleanWs()   // Always clean up the workspace after the build
    }
  }
 
} // end pipeline
