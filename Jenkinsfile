pipeline {
    agent any

    triggers {
        // No hay webhook publico desde un Jenkins local: revisa el repo
        // cada 5 minutos en busca de commits nuevos.
        pollSCM('H/5 * * * *')
    }

    environment {
        // Definida en Jenkins: Manage Jenkins > Credentials > Secret text
        // con ID "supabase_db_url". El valor real nunca esta en este archivo.
        SUPABASE_DB_URL = credentials('supabase_db_url')
    }

    stages {
        stage('Aplicar migraciones a Supabase') {
            steps {
                sh 'chmod +x scripts/apply_migrations.sh'
                sh './scripts/apply_migrations.sh "$SUPABASE_DB_URL"'
            }
        }
    }
}
