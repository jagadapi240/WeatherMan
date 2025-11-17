pipeline {
    agent any

    options {
        // We handle checkout ourselves in the 'Checkout' stage
        skipDefaultCheckout(true)
    }

    tools {
        // Must match the NodeJS tool name configured in Jenkins
        nodejs 'NodeJS16'
    }

    environment {
        // Docker image tag for WeatherMan
        DOCKER_IMAGE = "jagadapi240/weatherman:0.0.1-${BUILD_NUMBER}"

        // Nexus RAW repository details
        NEXUS_URL         = "51.21.202.150:8081"
        NEXUS_REPO        = "js"              // raw repo name (adjust if different)
        NEXUS_CREDENTIALS = "nexus-creds"     // Jenkins credentialsId

        // Sonar token (secret text in Jenkins)
        SONAR_TOKEN = credentials('sonar-token')
    }

    stages {

        /* 1. CLONE GITHUB */
        stage('Checkout') {
            steps {
                git branch: 'master', url: 'https://github.com/jagadapi240/WeatherMan.git'
            }
        }

        /* 2. INSTALL WEATHER MAN APP DEPENDENCIES */
        stage('Install Dependencies') {
            steps {
                sh 'npm install'
            }
        }

        /* 3. SONARQUBE SCAN */
        stage('SonarQube Analysis') {
            steps {
                sh """
                    npx sonar-scanner \
                      -Dsonar.projectKey=weatherman-js \
                      -Dsonar.projectName=WeatherMan \
                      -Dsonar.sources=src \
                      -Dsonar.host.url=http://sonarqube:9000 \
                      -Dsonar.login=${SONAR_TOKEN}
                """
            }
        }

        /* 4. BUILD WEATHER MAN (REACT) APP */
        stage('Build WeatherMan App') {
            steps {
                sh 'npm run build'
            }
        }

        /* 5. UPLOAD BUILD ARTIFACTS TO NEXUS RAW REPO */
        stage('Upload Build to Nexus') {
            steps {
                dir('build') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: "${NEXUS_CREDENTIALS}",
                            usernameVariable: 'NEXUS_USER',
                            passwordVariable: 'NEXUS_PASS'
                        )
                    ]) {
                        sh """
                            echo "Uploading build files to Nexus RAW repository..."

                            for file in \$(find . -type f); do
                                echo "Uploading: \$file"
                                curl -u "$NEXUS_USER:$NEXUS_PASS" \
                                  --upload-file "\$file" \
                                  "http://${NEXUS_URL}/repository/${NEXUS_REPO}/\${file}"
                            done
                        """
                    }
                }
            }
        }

        /* 6. BUILD DOCKER IMAGE */
        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${DOCKER_IMAGE} ."
            }
        }

        /* 7. PUSH IMAGE TO DOCKER HUB */
        stage('Push Docker Image') {
            steps {
                withDockerRegistry([credentialsId: 'dockerhub-creds', url: '']) {
                    sh "docker push ${DOCKER_IMAGE}"
                }
            }
        }

        /* 8. (OPTIONAL) DEPLOY CONTAINER */
        stage('Deploy Container') {
            steps {
                sh """
                    docker rm -f weatherman-app || true
                    docker run -d --name weatherman-app -p 8083:80 ${DOCKER_IMAGE}
                """
            }
        }
    }

    post {
        success {
            echo "SUCCESS! Docker image pushed → ${DOCKER_IMAGE}"
        }
        failure {
            echo "Pipeline Failed!"
        }
    }
}
