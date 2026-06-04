pipeline {
    agent none

    environment {
        // ECR registry + image repo (replaces Harbor linux02.local)
        ECR_REGISTRY = '445529239852.dkr.ecr.ap-east-1.amazonaws.com'
        IMAGE_NAME   = 'myapp/html5demos'
        IMAGE        = "${ECR_REGISTRY}/${IMAGE_NAME}"
        // TAG is set in the build stage (needs git SHA + a sh step), not here:
        // environment{} is evaluated before checkout and has no node context.
    }

    stages {
        stage('Static Files Check') {
            agent { label 'python' }
            steps {
                sh '''
                    echo "=== check index.html exists ==="
                    test -f index.html && echo "index.html found" || { echo "index.html missing!"; exit 1; }

                    echo "=== directory structure ==="
                    find . -maxdepth 2 -not -path "./.git/*" | sort

                    echo "=== basic HTML structure check ==="
                    python -c "
from html.parser import HTMLParser
class Checker(HTMLParser):
    def __init__(self):
        super().__init__()
        self.errors = []
    def handle_error(self, msg):
        self.errors.append(msg)

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

checker = Checker()
checker.feed(content)

if checker.errors:
    print('HTML issues:', checker.errors)
else:
    print('index.html structure check passed')
"
                '''
            }
        }

        stage('Build and Push to ECR') {
            agent { label 'kaniko' }
            steps {
                script {
                    // Capture SHA from checkout return value (env.GIT_COMMIT may be empty).
                    def scmVars = checkout scm
                    def gitSha  = scmVars.GIT_COMMIT.take(7)
                    // Fixed-width UTC timestamp -> lexical order == time order (newest-build).
                    def buildTs = new Date().format('yyyyMMddHHmmss', TimeZone.getTimeZone('UTC'))
                    // env.TAG (not def) so it persists across stages and is readable by sh.
                    env.TAG = "${buildTs}-${gitSha}"
                    echo "Image tag resolved: ${env.TAG}"
                }
                container('kaniko') {
                    // Single quotes: vars expanded by the shell from the environment.
                    sh '''
                        /kaniko/executor \
                          --context "${WORKSPACE}" \
                          --dockerfile "${WORKSPACE}/Dockerfile" \
                          --destination "${IMAGE}:${TAG}" \
                          --cache=true \
                          --cache-repo "${ECR_REGISTRY}/${IMAGE_NAME}/cache" \
                          --verbosity info
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Pushed image to ECR: ${IMAGE}:${env.TAG}"
            echo "Argo CD Image Updater will detect the new tag and write back to the chart repo."
        }
        failure {
            echo 'Pipeline failed, check the logs.'
        }
    }
}
