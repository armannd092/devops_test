# terraform project for devops test

this a terraform project for devops test. the infrastructure is based on aws.

---
## senario 1

Encryption management Key rotation on AWS

A new requirement from our regulators dictates that we must apply a
rotation on all of our KMS keys, the following diagram and technical details
illustrate how we’re implementing encryption on the cloud

Technical details
- Keys are managed on AWS KMS in a dedicated account, with external type (BYOK)
generated on our HSM hosted onpremise
- Encryption is segregated by environment and service, each environment has it’s own
key for each service
- Keys are using key alias
- key policy is implementing least privilege principle

---
## senario 2

APIs-as-a-Product Public and private APIs

We’re leveraging AWS to build and ship our APIs, both for internal usage
(API-driven integration between applications) and public usage
(customers, brokers..Etc). The following schema depicts how our APIs are
deployed on AWS.


Technical details
- All the APIs are “by design” public (even those who are not used publicly)
- APIs developed and maintained by different teams, but exposed through unique
endpoint (api.allianz-trade.com)
- All the APIs are protected with a global AWS WAFv2 and shield-advanced
- Backend microservices are either lambda functions or internal ALBs backing ECS
fargate microservices

---
## senario 4

Backup policy Laveraging AWS Backup

A new requirement dictates to implement a cloud backup policy on AWS using
AWS Backup service, automation is key when it comes to deploying at a scale
the backup policy, cloudfoundation team came up with a design validated by
security, compliance and architecture team illustrated underneath:

technical details & requirements

Plan definition
Backup frequency
Backup retention
Backup encryption

Resource selection
All supported resources
with
ToBackup=true
Owner=<owner@eulerher
mes.com.com


X-region/X-account copy

- Enable Cross-Region with defined frequency,retention & key

- Enable Cross-account with defined frequency,retention & key


WORM protection
- Enable Vault Lock to prevent malicious & accidental backup deletion




# How to run

init backend:

```sh

terraform init 

```

plan:

```sh

terraform plan -out inti.tfplan

```

apply:

```sh

terraform apply inti.tfplan

```

destroy:

```sh
terraform destroy

```
