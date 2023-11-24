variable "platform_api_key" {}
variable "accountId" {}
variable "endpoint" {}
variable "projectIdentifier" {}
variable "orgIdentifier" {}
variable "connectorIdentifier" {}
variable "k8sMasterUrl" {}
variable "secretIdentifier" {}
variable "secretValue" {}
variable "serviceIdentifier" {}
variable "envIdentifier" {}
variable "infraIdentifier" {}
variable "pipelineIdentifier" {}


terraform {  
    required_providers {  
        harness = {  
            source = "harness/harness"  
            version = "0.29.0"  
        }  
    }  
}

provider "harness" {  
    endpoint   = "${var.endpoint}"
    account_id = "${var.accountId}"
    platform_api_key    = "${var.platform_api_key}"
}

resource "harness_platform_project" "test" {
  identifier = "${var.projectIdentifier}"
  name       = "${var.projectIdentifier}"
  org_id     = "${var.orgIdentifier}"
  color      = "#0063F7"
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [harness_platform_project.test]

  create_duration = "30s"
}

resource "harness_platform_secret_text" "inline" {
  depends_on = [harness_platform_project.test, time_sleep.wait_30_seconds]
  identifier  = "${var.secretIdentifier}"
  name        = "${var.secretIdentifier}"
  description = "example"
  tags        = ["foo:bar"]
  org_id      = "${var.orgIdentifier}"
  project_id  = "${var.projectIdentifier}"
  secret_manager_identifier = "harnessSecretManager"
  value_type                = "Inline"
  value                     = "${var.secretValue}"
}


resource "harness_platform_connector_kubernetes" "serviceAccount" {
  depends_on = [harness_platform_project.test, harness_platform_secret_text.inline]
  identifier  = "${var.connectorIdentifier}"
  org_id      = "${var.orgIdentifier}"
  project_id  = "${var.projectIdentifier}"
  name        = "${var.connectorIdentifier}"
  description = "description"
  tags        = ["foo:bar"]
  service_account {
    master_url                = "${var.k8sMasterUrl}"
    service_account_token_ref = "${var.secretIdentifier}"
  }
}

resource "harness_platform_service" "example" {
  depends_on = [harness_platform_project.test]
  identifier  = "${var.serviceIdentifier}"
  org_id      = "${var.orgIdentifier}"
  project_id  = "${var.projectIdentifier}"
  name        = "${var.serviceIdentifier}"
  description = "description"
  tags        = ["foo:bar"]
  yaml = <<-EOT
                service:
                  name: "${var.serviceIdentifier}"
                  identifier: "${var.serviceIdentifier}"
                  tags: {}
                  serviceDefinition:
                    spec:
                      manifests:
                        - manifest:
                            identifier: manifest
                            type: K8sManifest
                            spec:
                              store:
                                type: Git
                                spec:
                                  connectorRef: org.GitConnectorForAutomationTest
                                  gitFetchType: Branch
                                  paths:
                                    - ng-automation/k8s/templates/
                                  branch: master
                              valuesPaths:
                                - ng-automation/k8s/values.yaml
                              skipResourceVersioning: false
                      artifacts:
                        primary:
                          primaryArtifactRef: <+input>
                          sources:
                            - spec:
                                connectorRef: org.DockerConnectorForAutomationTest
                                imagePath: library/nginx
                                tag: latest
                              identifier: artifact
                              type: DockerRegistry
                    type: Kubernetes
            EOT
}



resource "harness_platform_environment" "example" {
  depends_on = [harness_platform_project.test]
  identifier = "${var.envIdentifier}"
  name       = "${var.envIdentifier}"
  org_id     = "${var.orgIdentifier}"
  project_id = "${var.projectIdentifier}"
  tags       = ["foo:bar", "baz"]
  type       = "PreProduction"

  yaml = <<-EOT
                environment:
                  name: "${var.envIdentifier}"
                  identifier: "${var.envIdentifier}"
                  description: ""
                  tags: {}
                  type: PreProduction
                  orgIdentifier: "${var.orgIdentifier}"
                  projectIdentifier: "${var.projectIdentifier}"
                  variables: []
      EOT
}



resource "harness_platform_infrastructure" "example" {
  depends_on = [harness_platform_project.test, harness_platform_environment.example, harness_platform_connector_kubernetes.serviceAccount]
  identifier      = "${var.infraIdentifier}"
  name            = "${var.infraIdentifier}"
  org_id          = "${var.orgIdentifier}"
  project_id      = "${var.projectIdentifier}"
  env_id          = "${var.envIdentifier}"
  type            = "KubernetesDirect"
  deployment_type = "Kubernetes"
  yaml            = <<-EOT
                            infrastructureDefinition:
                              name: "${var.infraIdentifier}"
                              identifier: "${var.infraIdentifier}"
                              description: ""
                              tags: {}
                              orgIdentifier: "${var.orgIdentifier}"
                              projectIdentifier: "${var.projectIdentifier}"
                              environmentRef: "${var.envIdentifier}"
                              deploymentType: Kubernetes
                              type: KubernetesDirect
                              spec:
                                connectorRef: org.KubernetesConnectorForAutomationTest
                                namespace: default
                                releaseName: release-<+INFRA_KEY>
                              allowSimultaneousDeployments: true
      EOT
}



resource "harness_platform_pipeline" "example" {
  depends_on = [harness_platform_project.test, harness_platform_service.example, harness_platform_infrastructure.example]
  identifier = "${var.pipelineIdentifier}"
  org_id     = "${var.orgIdentifier}"
  project_id = "${var.projectIdentifier}"
  name       = "${var.pipelineIdentifier}"

  yaml = <<-EOT
                pipeline:
                  name: "${var.pipelineIdentifier}"
                  identifier: "${var.pipelineIdentifier}"
                  projectIdentifier: "${var.projectIdentifier}"
                  orgIdentifier: "${var.orgIdentifier}"
                  tags: {}
                  stages:
                    - stage:
                        name: stage
                        identifier: stage
                        description: ""
                        type: Deployment
                        spec:
                          deploymentType: Kubernetes
                          service:
                            serviceRef: "${var.serviceIdentifier}"
                            serviceInputs:
                              serviceDefinition:
                                type: Kubernetes
                                spec:
                                  artifacts:
                                    primary:
                                      primaryArtifactRef: <+input>
                                      sources: <+input>
                          environment:
                            environmentRef: "${var.envIdentifier}"
                            deployToAll: false
                            infrastructureDefinitions:
                              - identifier: "${var.infraIdentifier}"
                          execution:
                            steps:
                              - step:
                                  name: Rollout Deployment
                                  identifier: rolloutDeployment
                                  type: K8sRollingDeploy
                                  timeout: 10m
                                  spec:
                                    skipDryRun: false
                                    pruningEnabled: false
                            rollbackSteps:
                              - step:
                                  name: Rollback Rollout Deployment
                                  identifier: rollbackRolloutDeployment
                                  type: K8sRollingRollback
                                  timeout: 10m
                                  spec:
                                    pruningEnabled: false
                        tags: {}
                        failureStrategies:
                          - onFailure:
                              errors:
                                - AllErrors
                              action:
                                type: StageRollback
                        variables:
                          - name: resourceNamePrefix
                            type: String
                            description: ""
                            value: qwe
  EOT
}