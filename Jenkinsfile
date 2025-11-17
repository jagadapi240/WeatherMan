pipeline {
    agent any

    environment {
        // DockerHub image for WeatherMan
        DOCKER_IMAGE = 'jagadapi240/weatherman'
    }

    stages {

        /* 1. CHECKOUT SOURCE CODE */
        stage('SCM Checkout') {
            steps {
                checkout scm
            }
        }

        /* 2. INSTALL DEPENDENCIES & BUILD (npm) */
        stage('Build WeatherMan App') {
            steps {
                sh '''
                    echo "Installing npm dependencies..."
                    npm install

                    echo "Running production build..."
                    npm run build

                    echo "Build completed. Build folder contents:"
                    ls -R build || echo "No build folder found!"
                '''
            }
        }

        /* 3. BUILD DOCKER IMAGE FROM DOCKERFILE */
        stage('Build Docker Image') {
            steps {
                sh """
                    echo "Building Docker image ${DOCKER_IMAGE}:${BUILD_NUMBER}"
                    docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} .
                """
            }
        }

        /* 4. PUSH IMAGE TO DOCKERHUB (uses dockerhub-creds) */
        stage('Push to DockerHub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DH_USER',
                        passwordVariable: 'DH_PASS'
                    )
                ]) {
                    sh """
                        echo "Logging into DockerHub as ${DH_USER}"
                        echo "${DH_PASS}" | docker login -u "${DH_USER}" --password-stdin

                        echo "Tagging image..."
                        docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest

                        echo "Pushing images..."
                        docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
                        docker push ${DOCKER_IMAGE}:latest
                    """
                }
            }
        }

        /* 5. DEPLOY CONTAINER ON docker-js SERVER */
        stage('Deploy Docker Container') {
            steps {
                sh """
                    echo "Stopping old WeatherMan container if exists..."
                    docker rm -f weatherman-app || true

                    echo "Starting new WeatherMan container..."
                    docker run -d \
                      --name weatherman-app \
                      -p 8083:80 \
                      ${DOCKER_IMAGE}:${BUILD_NUMBER}

                    echo "WeatherMan is live at: http://<SERVER-IP>:8083"
                """
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}
