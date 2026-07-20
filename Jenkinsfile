pipeline {
    agent any

    tools {
        maven 'maven-3' 
        // We removed the jdk 'jdk-17' tool from here since we are hardcoding it below
    }

    stages {
        stage('Code Quality (SonarQube)') {
            steps {
                script {
                    def mvnHome = tool name: 'maven-3', type: 'maven'
                    
                    // Hardcode the native Ubuntu JDK 17 path
                    def javaHome = '/usr/lib/jvm/java-17-openjdk-amd64'
                    
                    withEnv(["JAVA_HOME=${javaHome}", "PATH=${mvnHome}/bin:${javaHome}/bin:${env.PATH}"]) {
                        echo 'Scanning code with SonarQube...'
                        sh 'mvn --version' 
                        
                        // IMPORTANT: Replace YOUR_COPIED_TOKEN below with your actual SonarQube token!
                        sh 'mvn clean verify sonar:sonar -Dsonar.projectKey=employee-app -Dsonar.host.url=http://localhost:9000 -Dsonar.login=YOUR_COPIED_TOKEN'
                    }
                }
            }
        }

        stage('Build Java App') {
            steps {
                script {
                    def mvnHome = tool name: 'maven-3', type: 'maven'
                    
                    // Hardcode the native Ubuntu JDK 17 path here too
                    def javaHome = '/usr/lib/jvm/java-17-openjdk-amd64'
                    
                    withEnv(["JAVA_HOME=${javaHome}", "PATH=${mvnHome}/bin:${javaHome}/bin:${env.PATH}"]) {
                        echo 'Compiling and building the JAR file...'
                        sh 'mvn clean package -DskipTests'
                    }
                }
            }
        }

        stage('Determine Environment (Blue/Green)') {
            steps {
                script {
                    def currentPort = sh(script: "grep -o '127.0.0.1:[0-9]*' /etc/nginx/conf.d/employee-app.conf | cut -d ':' -f 2 || echo 'none'", returnStdout: true).trim()
                    
                    if (currentPort == '8081') {
                        env.NEW_ENV = 'green'
                        env.NEW_PORT = '8082'
                        env.OLD_ENV = 'blue'
                    } else {
                        env.NEW_ENV = 'blue'
                        env.NEW_PORT = '8081'
                        env.OLD_ENV = 'green'
                    }
                    echo "Currently active on ${currentPort}. Deploying to ${env.NEW_ENV} on port ${env.NEW_PORT}."
                }
            }
        }

        stage('Deploy New Environment') {
            steps {
                echo "Starting MySQL and the new ${env.NEW_ENV} environment..."
                sh "docker-compose up --build -d mysql-db employee-app-${env.NEW_ENV}"
            }
        }

        stage('Wait for Health Check') {
            steps {
                echo "Waiting for the ${env.NEW_ENV} environment to report healthy..."
                script {
                    retry(12) { 
                        sleep 5
                        sh "curl --silent --fail http://localhost:${env.NEW_PORT}/actuator/health"
                    }
                }
            }
        }

        stage('Traffic Cutover (NGINX)') {
            steps {
                echo "Health check passed! Switching NGINX traffic to ${env.NEW_ENV}..."
                sh "sudo sed -i 's/server 127.0.0.1:.*/server 127.0.0.1:${env.NEW_PORT};/' /etc/nginx/conf.d/employee-app.conf"
                sh "sudo systemctl restart nginx"
            }
        }

        stage('Teardown Old Environment') {
            steps {
                echo "Traffic is live on ${env.NEW_ENV}. Shutting down ${env.OLD_ENV}..."
                sh "docker stop employee-app-${env.OLD_ENV} || true"
                sh "docker rm employee-app-${env.OLD_ENV} || true"
            }
        }
    }

    post {
        always {
            echo "Deployment pipeline finished. Cleaning up temporary Docker artifacts."
            sh "docker system prune -f"
        }
        success {
            echo "PIPELINE SUCCESS! Users are now on the ${env.NEW_ENV} environment."
        }
        failure {
            echo "PIPELINE FAILED! The live environment was NOT swapped and users are unaffected."
        }
    }
}
