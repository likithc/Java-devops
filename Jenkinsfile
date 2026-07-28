pipeline {
    agent { 
        label 'local-k8s-agent' 
    }

   stage('Checkout SCM') {
    steps {
        checkout scm
    }
}
        
        stage('Build Maven App') {
            steps {
                // Compiles your Java application (creates the jar inside target/)
                sh 'mvn clean package -DskipTests'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                // Builds the Spring Boot image using your root Dockerfile
                sh 'docker build -t employee-app:latest .'
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                // Applies all configurations in your k8s folder to your local cluster
                sh 'kubectl apply -f k8s/'
            }
        }
    }
}
