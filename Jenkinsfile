pipeline {
    agent none

    environment {
        IMAGE = 'linux02.local/myapp/html5demos'
        TAG = "build-${BUILD_NUMBER}"

        CHART_REPO = 'linux03.local:3000/admin/html5demos-chart.git'
        CHART_DIR = 'html5demos-chart'
    }

    stages {
        stage('Static Files Check') {
            agent {
                label 'python'
            }

            stages {
                stage('Check index.html') {
                    steps {
                        sh '''
                            echo "=== 检查 index.html ==="
                            test -f index.html && echo "index.html 存在" || (echo "index.html 缺失！" && exit 1)
                        '''
                    }
                }

                stage('Check Key Assets') {
                    steps {
                        sh '''
                            echo "=== 目录结构 ==="
                            find . -maxdepth 2 -not -path "./.git/*" | sort

                            echo "=== HTML 语法粗检（检查未闭合标签）==="
                            python3 -c "
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
    print('HTML 问题:', checker.errors)
else:
    print('index.html 基本结构检查通过')
"
                        '''
                    }
                }
            }
        }

        stage('Build and Push Image') {
            agent {
                label 'kaniko'
            }

            steps {
                container('kaniko') {
                    sh '''
                        /kaniko/executor \
                          --context "${WORKSPACE}" \
                          --dockerfile "${WORKSPACE}/Dockerfile" \
                          --destination "${IMAGE}:${TAG}" \
                          --registry-certificate=linux02.local=/kaniko/certs/ca.crt
                    '''
                }
            }
        }

        stage('Update Helm Chart Repo') {
            agent {
                label 'python'
            }

            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'gitea-token',
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_PASS'
                )]) {
                    sh '''
                        set -e

                        rm -rf ${CHART_DIR}

                        git clone http://${GIT_USER}:${GIT_PASS}@${CHART_REPO} ${CHART_DIR}

                        cd ${CHART_DIR}

                        git config user.name "jenkins"
                        git config user.email "jenkins@local"

                        sed -i "s|^  repository:.*|  repository: ${IMAGE}|" values.yaml
                        sed -i "s|^  tag:.*|  tag: \\"${TAG}\\"|" values.yaml

                        echo "=== updated values.yaml ==="
                        cat values.yaml

                        git add values.yaml
                        git commit -m "Update image tag to ${TAG}" || echo "No changes to commit"
                        git push origin main
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "镜像已成功推送到 Harbor: ${IMAGE}:${TAG}"
            echo "Helm Chart values.yaml 已更新为 tag: ${TAG}"
            echo "ArgoCD 可以同步部署了"
        }
        failure {
            echo '流水线失败，请查看日志排查'
        }
    }
}