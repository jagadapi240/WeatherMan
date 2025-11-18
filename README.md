```🌦️ WeatherMan — Full CI/CD on AWS (Docker + Jenkins + GitHub Actions + SonarQube + Nexus + EC2)

This project implements a complete CI/CD pipeline for the **WeatherMan React JavaScript application**, deployed automatically to AWS EC2 using:

- Docker
- Jenkins Pipeline
- GitHub Actions
- SonarQube
- Nexus Repository Manager
- DockerHub
- ED25519 SSH secure deploy
- AWS EC2 Ubuntu Linux

Final Production App URL:  
👉 http://13.61.2.205:8083

---

# 1. PROJECT ARCHITECTURE

```

GitHub (WeatherMan Repo)
│
├── GitHub Actions CI/CD
│      ├ Install Node
│      ├ Sonar Scan
│      ├ Build React App
│      ├ Build Docker Image
│      ├ Push to DockerHub
│      └ Deploy to EC2 via SSH
│
└── Jenkins CI/CD (Running in Docker on EC2)
├ Checkout Code
├ Node Install
├ SonarQube Scan (Dockerized scanner)
├ Upload build files to Nexus RAW Repo
├ Build Docker Image
├ Push DockerHub Image
└ Deploy to EC2 via Publish Over SSH

````

EC2 Also Hosts:

- Jenkins (8080)
- SonarQube (9000)
- Nexus (8081)
- WeatherMan App (8083)

---

# 2. EC2 SERVER SETUP

SSH into your EC2:

```bash
ssh -i key.pem ubuntu@13.61.2.205
````

Install Docker:

```bash
sudo hostnamectl set-hostname docker-js
sudo init 6
sudo apt -y update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo chmod 666 /var/run/docker.sock
```

Create network:

```bash
docker network create cicd-net
docker network ls
```

---

# 3. DOCKER CONTAINERS (JENKINS, NEXUS, SONARQUBE)

## SONARQUBE

```bash
docker run -d --name sonarqube --network cicd-net -p 9000:9000 -v /home/ubuntu/sonar-data:/var/sonar-data sonarqube:lts
```

## NEXUS

```bash
docker run -d --name nexus --network cicd-net -p 8081:8081 -v /home/ubuntu/nexus-data:/var/nexus-data sonatype/nexus3
```

Check Nexus internal IP:

```bash
docker inspect nexus | grep IPAddress
```

Used internal IP:
**172.18.0.3**

Create Nexus RAW repo named: **js**

## JENKINS

```bash
docker run -dt --name jenkins --network cicd-net -p 8080:8080 -v /home/ubuntu/jenkins-data:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock jenkins/jenkins:lts-jdk17
```

Get password:

```bash
docker exec -it jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

---

# 4. JENKINS SETUP (PLUGINS, TOOLS, CREDENTIALS)

## REQUIRED JENKINS PLUGINS

Install:

* Git Plugin
* NodeJS Plugin
* Docker Pipeline
* Publish Over SSH
* Credentials Binding
* Pipeline-Stageview

---

## INSTALL DEPENDENCIES INSIDE JENKINS CONTAINER

```bash
docker exec -it --user root jenkins bash
apt-get update
apt-get install -y docker.io
apt-get install -y nodejs npm
apt-get install -y zip unzip
```

Fixes:

* `docker: not found`
* `npm: not found`

---

## NODEJS TOOL CONFIGURATION

Manage Jenkins → Global Tool Configuration → NodeJS

* Name: **NodeJS16**
* NodeJS16.20.4
* Installation directory: leave blank

---

## JENKINS CREDENTIALS

| ID              | TYPE                          | USED FOR       |
| --------------- | ----------------------------- | -------------- |
| sonar-token     | Secret Text                   | Sonar Login    |
| nexus-creds     | Username/Password             | Nexus Upload   |
| dockerhub-creds | Username/Password             | DockerHub Push |
| EC2-Server      | SSH Server (Publish Over SSH) | Deploy via SSH |

EC2-Server includes private ED25519 key.
<img width="1920" height="1080" alt="5" src="https://github.com/user-attachments/assets/f58a4fc9-a4c7-492c-973e-0d6b96ed59eb" />


---

# 5. SSH DEPLOYMENT (ED25519 KEY)

## GENERATE KEY

You executed:

```bash
ssh-keygen
```

## ADD PUBLIC KEY TO EC2

```bash
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

This fixed:

```
ssh: handshake failed: publickey error
```

Use `id_ed25519` as private key in:

* GitHub Secrets
* Jenkins Publish Over SSH

---

# 6. DOCKERFILE

File: `Dockerfile`

```dockerfile
# Step 1: Build stage with Node 16 (works with old react-scripts/webpack)
FROM node:16-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

# Build the production bundle (creates build/ folder)
RUN npm run build

# Step 2: Run stage (Nginx)
FROM nginx:alpine

COPY --from=build /app/build/ /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```
<img width="1920" height="1080" alt="2" src="https://github.com/user-attachments/assets/9140d414-219c-445b-84d8-a6f44b6cf863" />
<img width="1920" height="1080" alt="3" src="https://github.com/user-attachments/assets/e971a2f9-5206-4d33-a2af-3f8762576829" />

---

# 7. JENKINSFILE

```groovy
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
                            credentialsId: 'nexus-creds',   // your Nexus creds ID
                            usernameVariable: 'NEXUS_USER',
                            passwordVariable: 'NEXUS_PASS'
                        )
                    ]) {
                        sh '''
                            echo "Uploading build files to Nexus RAW repository..."

                            for file in $(find . -type f); do
                                echo "Uploading: $file"
                                curl -u "$NEXUS_USER:$NEXUS_PASS" \
                                --upload-file "$file" \
                                "http://nexus:8081/repository/js/${file#./}"
                            done
                        '''
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
```
<img width="1920" height="1080" alt="6" src="https://github.com/user-attachments/assets/9630b093-a778-450b-bf42-f53a85ac88e8" />
<img width="1920" height="1080" alt="8" src="https://github.com/user-attachments/assets/b4413fe1-9258-4fdc-bcad-0855734f6d98" />
<img width="1920" height="1080" alt="1" src="https://github.com/user-attachments/assets/6b5959af-b880-48b6-b3a7-ed3ae810a59b" />
<img width="1920" height="1080" alt="4" src="https://github.com/user-attachments/assets/03a0f70e-d5ce-4238-afb4-5febc76e1eed" />



---

# 8. GITHUB ACTIONS WORKFLOW

File: `.github/workflows/weatherman-ci-cd.yml`

```yaml
name: WeatherMan CI/CD

on:
  push:
    branches:
      - master
  workflow_dispatch:

env:
  APP_NAME: weatherman
  IMAGE_NAME: jagadapi240/weatherman
  IMAGE_VERSION: 0.0.1

jobs:
  build-and-push:
    runs-on: ubuntu-latest

    steps:

      # 1) CHECKOUT CODE -----------------------------------------
      - name: Checkout repository
        uses: actions/checkout@v4

      # 2) NODE SETUP & REACT BUILD ------------------------------
      - name: Set up Node 16
        uses: actions/setup-node@v4
        with:
          node-version: 16

      - name: Install npm dependencies
        run: npm install

      - name: Build WeatherMan App
        run: npm run build

      # 3) SONARQUBE SCAN ----------------------------------------
      - name: SonarQube Scan
        env:
          SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        run: |
          echo "Running SonarQube scan..."
          docker run --rm \
            -e SONAR_HOST_URL="$SONAR_HOST_URL" \
            -v "${{ github.workspace }}":/usr/src \
            sonarsource/sonar-scanner-cli \
            -Dsonar.projectKey=weatherman-js \
            -Dsonar.projectName=WeatherMan \
            -Dsonar.sources=./src \
            -Dsonar.host.url="$SONAR_HOST_URL" \
            -Dsonar.login="$SONAR_TOKEN"

      # 4) DOCKER BUILD ------------------------------------------
      - name: Build Docker image
        run: |
          IMAGE_TAG=${{ env.IMAGE_VERSION }}-${{ github.run_number }}
          echo "Building: ${{ env.IMAGE_NAME }}:${IMAGE_TAG}"
          docker build -t ${{ env.IMAGE_NAME }}:${IMAGE_TAG} .

      # 5) PUSH TO DOCKER HUB ------------------------------------
      - name: Login to Docker Hub
        run: echo "${{ secrets.DOCKERHUB_TOKEN }}" | docker login -u "${{ secrets.DOCKERHUB_USERNAME }}" --password-stdin

      - name: Push Docker image
        run: |
          IMAGE_TAG=${{ env.IMAGE_VERSION }}-${{ github.run_number }}
          docker push ${{ env.IMAGE_NAME }}:${IMAGE_TAG}
          docker tag ${{ env.IMAGE_NAME }}:${IMAGE_TAG} ${{ env.IMAGE_NAME }}:latest
          docker push ${{ env.IMAGE_NAME }}:latest

  # DEPLOY JOB --------------------------------------------------
  deploy:
    runs-on: ubuntu-latest
    needs: build-and-push

    steps:
      - name: Deploy to EC2 via SSH
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ${{ secrets.EC2_USER }}
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            IMAGE_TAG=${{ env.IMAGE_VERSION }}-${{ github.run_number }}
            IMAGE_FULL=${{ env.IMAGE_NAME }}:${IMAGE_TAG}

            echo "Pulling latest Docker image $IMAGE_FULL"
            docker pull $IMAGE_FULL

            echo "Stopping old container"
            docker rm -f weatherman-app || true

            echo "Starting new container"
            docker run -d \
              --name weatherman-app \
              -p 8083:80 \
              $IMAGE_FULL

            docker ps | grep weatherman-app || echo "Container not running!"
```
9. GITHUB SECRETS REQUIRED
   
WeatherMan -> Settings -> Secrets and Variables -> Actions -> New repository secret

| Secret           | Value                  |
| ---------------- | ---------------------- |
| SONAR_TOKEN      | SonarQube token        |
| DOCKER_HUB_USER  | jagadapi240            |
| DOCKER_HUB_TOKEN | DockerHub PAT          |
| EC2_HOST         | 13.61.2.205            |
| EC2_USER         | ubuntu                 |
| EC2_SSH_KEY      | Contents of id_ed25519 |


<img width="1920" height="1080" alt="9" src="https://github.com/user-attachments/assets/5c38a9cd-9a1b-4f22-b242-1a2800507443" />
<img width="1920" height="1080" alt="10" src="https://github.com/user-attachments/assets/789a7beb-5baa-4a80-8553-8c0644081c9c" />
<img width="1920" height="1080" alt="11" src="https://github.com/user-attachments/assets/634c47bf-6546-4a99-8320-c15da12aab9f" />
<img width="1920" height="1080" alt="12" src="https://github.com/user-attachments/assets/9e4bf757-241d-45a6-88a8-3cb0f69911b7" />



# 10. FINAL APP URL

👉 [http://13.61.2.205:8083](http://13.61.2.205:8083)

---

# 11. ALL ERRORS YOU FACED (AND FIXES INCLUDED)

| Error                  | Fix                                          |
| ---------------------- | -------------------------------------------- |
| `docker: not found`    | Installed docker.io inside Jenkins container |
| `npm: not found`       | Installed nodejs + npm                       |                |
| Webpack crypto error   | NODE_OPTIONS=--openssl-legacy-provider       |
| Sonar “not authorized” | Passed sonar.login token                     |
| Nexus upload hanging   | Used internal IP 172.18.0.3                  |
| SSH handshake failed   | Added ED25519 key to authorized_keys         |

---


Just say: **"Generate PDF"**
```
