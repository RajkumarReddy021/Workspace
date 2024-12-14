pipeline {
    agent any

    stages {
        stage('Checkout Code') {
            steps {
                git url: 'https://github.com/RajkumarReddy021/Workspace.git', branch: 'main'
            }
        }

        stage('Terraform Init') {
            steps {
                script {
                    echo "Initializing Terraform..."
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                script {
                    echo "Running terraform plan..."
                    sh 'terraform plan'
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                script {
                    echo "Running terraform apply..."
                    sh 'terraform apply --auto-approve'
                }
            }
        }

        stage('Terraform Destroy') {
            when {
                expression {
                    // Check if user wants to run terraform destroy
                    return input(message: 'Do you want to destroy the infrastructure?', parameters: [choice(name: 'Action', choices: ['Run', 'Skip'], description: 'Choose whether to run terraform destroy')]) == 'Run'
                }
            }
            steps {
                script {
                    echo "Running terraform destroy"
                    sh 'terraform destroy --auto-approve'
                }
            }
        }
    }

    post {
        success {
            echo 'Terraform deployment was successful!'
        }

        failure {
            echo 'Terraform deployment failed!'
        }
    }
}
