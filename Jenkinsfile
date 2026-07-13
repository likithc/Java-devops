pipeline {
    agent any

    environment {
        // Core Variables
        DOCKER_IMAGE = "employee-app"
        IMAGE_TAG = "v${env.BUILD_ID}"
        
        // NGINX configuration path on the host server
        NGINX_CONF_DIR = "/etc/nginx/conf.d"
    }

    stages {
        stage('Unit Tests & Maven Package') {
            steps {
                echo "Running tests to prevent broken code from deploying..."
                sh 'mvn clean test package'
            }
        }

        stage('Build & Tag Docker Image') {
            steps {
                echo "Building lightweight Docker image..."
                sh "docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} -t ${DOCKER_IMAGE}:latest ."
            }
        }

        stage('Determine Target Environment') {
            steps {
                script {
                    // Check if Blue is currently running and active
                    def isBlueActive = sh(script: "docker ps | grep employee-app-blue", returnStatus: true) == 0
                    
                    if (isBlueActive) {
                        env.ACTIVE_ENV = "blue"
                        env.NEW_ENV = "green"
                        env.NEW_PORT = "8082"
                    } else {
                        // If Blue isn't active, we assume Green is (or it's the first run)
                        env.ACTIVE_ENV = "green"
                        env.NEW_ENV = "blue"
                        env.NEW_PORT = "8081"
                    }
                    echo "Currently Active: ${env.ACTIVE_ENV}. Deploying to: ${env.NEW_ENV} on port ${env.NEW_PORT}"
                }
            }
        }

        stage('Spin Up New Environment') {
            steps {
                // We use Docker Compose to target just the idle service
                sh "docker-compose up -d --build employee-app-${env.NEW_ENV}"
            }
        }

        stage('Wait for Health Check') {
            steps {
                echo "Waiting for the ${env.NEW_ENV} environment to report healthy..."
                script {
                    // Retry every 5 seconds for up to 1 minute
                    retry(12) {
                        sleep 5
                        // Ensure the Spring Boot actuator endpoint returns a 200 OK
                        sh "curl --silent --fail http://localhost:${env.NEW_PORT}/actuator/health"
                    }
                }
            }
        }

        stage('Traffic Cutover (NGINX)') {
            steps {
                echo "Health check passed! Switching NGINX traffic to ${env.NEW_ENV}..."
                // Update the NGINX upstream port securely using sed
                sh "sudo sed -i 's/server 127.0.0.1:.*/server 127.0.0.1:${env.NEW_PORT};/' ${NGINX_CONF_DIR}/employee-app.conf"
                
                // Reload NGINX gracefully without dropping active connections
                sh "sudo systemctl reload nginx"
            }
        }

        stage('Teardown Old Environment') {
            steps {
                script {
                    // Only tear down the old container if it actually exists (skip on first run)
                    def oldExists = sh(script: "docker ps -a | grep employee-app-${env.ACTIVE_ENV}", returnStatus: true) == 0
                    if (oldExists) {
                        echo "Traffic cutover complete. Shutting down the old ${env.ACTIVE_ENV} environment..."
                        sh "docker-compose stop employee-app-${env.ACTIVE_ENV}"
                        sh "docker-compose rm -f employee-app-${env.ACTIVE_ENV}"
                    } else {
                        echo "No previous environment to clean up. (First deployment)"
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Deployment pipeline finished. Cleaning up temporary Docker artifacts."
            sh 'docker system prune -f'
        }
        failure {
            echo "PIPELINE FAILED! The live environment was NOT swapped and users are unaffected."
        }
    }
}
