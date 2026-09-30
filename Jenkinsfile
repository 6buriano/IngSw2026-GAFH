pipeline {
    agent any

    parameters {
        string(name: 'SOURCE_DIR', defaultValue: '/deployments/source', description: 'Ruta del directorio origen con el nuevo código fuente descargado')
        string(name: 'TARGET_DIR', defaultValue: '/deployments/target', description: 'Ruta del directorio destino donde se copiará, testeará y desplegará')
    }

    environment {
        // Asegurar codificación UTF-8
        LANG = 'C.UTF-8'
    }

    stages {
        stage('1. Copiar Código Fuente') {
            steps {
                echo "=========================================================="
                echo " ETAPA 1: Copiando nueva versión del sistema"
                echo " Origen:  ${params.SOURCE_DIR}"
                echo " Destino: ${params.TARGET_DIR}"
                echo "=========================================================="
                sh '''
                    # Validar existencia de la carpeta origen
                    if [ ! -d "${SOURCE_DIR}" ]; then
                        echo "ERROR: El directorio origen '${SOURCE_DIR}' no existe."
                        exit 1
                    fi

                    # Crear directorio destino si no existe
                    mkdir -p "${TARGET_DIR}"

                    # Copiar el código fuente desde origen hacia destino
                    cp -rf "${SOURCE_DIR}/." "${TARGET_DIR}/"

                    echo ">>> Archivos copiados exitosamente al directorio destino:"
                    ls -la "${TARGET_DIR}"
                '''
            }
        }

        stage('2. Testear Sistema') {
            steps {
                echo "=========================================================="
                echo " ETAPA 2: Ejecución de Pruebas Automatizadas (Testing)"
                echo "=========================================================="
                dir("${params.TARGET_DIR}") {
                    sh '''
                        # Verificar que exista el archivo de configuración de Maven
                        if [ ! -f "pom.xml" ]; then
                            echo "ERROR: pom.xml no encontrado en el directorio destino."
                            exit 1
                        fi

                        echo ">>> Ejecutando pruebas unitarias con Maven..."
                        mvn clean test
                    '''
                }
            }
        }

        stage('3. Desplegar con Docker') {
            steps {
                echo "=========================================================="
                echo " ETAPA 3: Despliegue de Contenedores Docker"
                echo "=========================================================="
                dir("${params.TARGET_DIR}") {
                    sh '''
                        # Verificar que exista docker-compose.yml
                        if [ ! -f "docker-compose.yml" ]; then
                            echo "ERROR: docker-compose.yml no encontrado en el directorio destino."
                            exit 1
                        fi

                        echo ">>> Reconstruyendo y desplegando servicios..."
                        # Reconstruir y actualizar el contenedor de la aplicación
                        docker compose up -d --build app_java

                        echo ">>> Estado actual de los contenedores:"
                        docker compose ps
                    '''
                }
            }
        }

        stage('4. Verificación de Salud') {
            steps {
                echo "=========================================================="
                echo " ETAPA 4: Verificación del Despliegue"
                echo "=========================================================="
                sh '''
                    echo "Esperando 10 segundos a que la aplicación inicie..."
                    sleep 10

                    echo ">>> Verificando disponibilidad de la API..."
                    # Comprobar si responde el endpoint de productos o swagger
                    curl -s -o /dev/null -w "Código HTTP respuesta API: %{http_code}\n" http://app_java:8080/api/productos || true
                '''
            }
        }
    }

    post {
        success {
            echo "=========================================================="
            echo " [OK] PIPELINE COMPLETADO EXITOSAMENTE"
            echo " La nueva versión fue copiada, testeada y desplegada."
            echo "=========================================================="
        }
        failure {
            echo "=========================================================="
            echo " [FAIL] ERROR EN LA EJECUCIÓN DEL PIPELINE"
            echo " Por favor revise los logs anteriores para más detalles."
            echo "=========================================================="
        }
    }
}
