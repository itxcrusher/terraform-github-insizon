# Project Goal


## Note
1. Feel free to remove / rename folders and files
2. Feel free create custom shell script or python script if something is not possible with terraform.



## Project Table Of Context
1. Seperate terraform state for each env(prod, qa, dev)
2. Point all other terraform states to remote AWS S3 bucket (Ex. terraformGithub)
3. Add additional AWS Modules (Glacier, AWS SMS, Amazon RDS for PostgreSQL, Temp Access)
4. Update Custom Github Actions. (Composite Action, Javascript/Typescript)
5. TerraformGithub




## Seperate terraform state for each env(prod, qa, dev)
- Note -> I'll give you access to the terraformAws, insizonGithubWorkflows, etc github repo
Doing this will allow for extra protection for new testing changes bc sometimes might need to use terraform destory
1. Instead of having one mono terraform state file. I would like a different terraform state file for each environment
2. For example the AWS project has yaml property env: <env>
(apps.yaml, cloudfront.yaml, ecr.yaml, elasticbeanstalk.yaml, and lambda-event.yaml)
3. When terraform changes is pushed or merged into the branch (main[prod], qa[qa], dev[dev]) the terraform apply command is ran using Github Action.


## Point all other terraform states to remote AWS S3 bucket (Ex. terraformGithub)
1. Currently the terraformAWS project has a remote terraform state in Aws s3 bucket and the terraformAzure has remote terraform state in
azure storage account
2. I want all other terraform projects such as terraformGithub to have it's remote state store in another terraform state file in the (insizon-terraform-remote-state-backend-bucket) bucket


## Add additional AWS Modules (Glacier, AWS SMS, Amazon RDS for PostgreSQL, Temp Access)
1. Add this additional AWS modules to terraformAWS project - Glacier, AWS SMS, Amazon RDS for PostgreSQL
2. These additional modules should be in seperate yaml file
3. For the Glacier and AWS SMS(https://www.youtube.com/watch?v=_nqkjGmI0DE) module I will provide the typescript class must be used and updated/tested to work


## Update Custom Github Actions. (Composite Action, Javascript/Typescript)
1. I will give you access to insizonGithubWorkflows
2. Update all the github composite actions that are marked as Uncomplete at the top of each file
3. Add example of how to call the action either at top of file or in seperate file
4. Add basic example publish of package to publish


## TerraformGithub
1. Create script that 
- Will upload private and public rsa keys, and other secrets to github oranganization secrets
so that you don't have to upload secrets in repo
2. Create Project repo
  a. Read from a yaml file
  b. Ability to attach Organization secrets to repo
  c. Add Repository secrets
  d. Add Environment secrets
  e. Create branch (main, dev, qa)
  f. Create repo or public
  g. Ruleset (PR, deletion protection, etc)
  h. Create custom roles
  i. Ability to import already existing repos
3. Secrets
  1. Read from a yaml file
  2. Create Organization secrets
  4. Out to folder that is gitignored ()
4. Create Teams
  a. Read from a yaml file
  b. Ability to add user to team base on yaml property
  Ex.
    teamName: insizon-team
    fullName: Insizon Team
    description: "Some cool team"
    privacy: "closed"
    repos:
      - insizon-dev
      - insizon-prod
5. Create Users
  a. Read from a yaml file
  b. Users should only be limited to specific repos via custom teams (Frontend Team, Backend Team, Cloud Team, other)
  Should be able to list team name, and repo team has access too.
  Ex.
    userName: 
    fullName
    teamName: insizon-team
    role: readOnly
    repos:
      - insizon-dev
      - insizon-prod
6. Create Other
  a. Read from a yaml file
  b. Ability to create classic tokens
  c. Ability to create github new token
  d. Ability to create GPG keys
  e. Ability to create SSH keys
  f. Create organation webhooks
  g. Create repo webhooks
  h. Create github actions
  j. Create Deployment Keys (SSH Keys)



## Managing Secrets
1. As, you may know that secrets are output to local file when resources is being created. I know that can look for the secret in remote
terraform state but I would the ability to get secret back in local when I switch devices. For example, if I log into another device and pull down the terraformAWS repo those secret local such rsa will not be there as they are gitignored. 
2. Solution Suggestions? -> 
  a. Write custom script python/shell to send the secrets to AWD RDS table, which will allow for updating and pulling down secrets when on new device
  b. Store the secrets as Github repo secrets
  c. ???
Example??
```yml
name: Add Secret to Repository
on: push

jobs:
  add_secret:
    runs-on: ubuntu-latest
    steps:
      - name: Add secret using github-script
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.actions.createOrUpdateRepoSecret({
              owner: context.repo.owner,
              repo: context.repo.repo,
              secret_name: 'MY_SECRET',
              encrypted_value: 'YOUR_ENCRYPTED_SECRET_VALUE', // Replace with your encrypted secret
              visibility: 'all',
            });

      - name: Add secret using GitHub CLI
        run: |
          echo "::add-mask::${{ secrets.GITHUB_TOKEN }}"
          echo "::add-mask::YOUR_SECRET_VALUE" # Replace with your secret value
          gh secret set MY_SECRET --body "YOUR_SECRET_VALUE" --repo "${{ github.repository }}"
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```