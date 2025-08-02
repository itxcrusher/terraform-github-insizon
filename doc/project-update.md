## Project Update




## Project Table Of Content
1. Add AWS CodeBuilder module
2. Switch from Github Action to AWS CodeBuilder for terraform projects
3. Store Local Files/Cred
4. Add new property to yaml files



## Add AWS CodeBuilder module
1. Will be needed for project building terraform projects
2. Create seperate yaml file
3. List all nessecary properties



## Switch from Github Action to AWS CodeBuilder for terraform projects
- Useful link on AWS CodeBuilder -> https://www.youtube.com/watch?v=IcNiOdYzBEM&list=PL184oVW5ERMALkQpNuSLMAYpPGLkRYpxN
1. Will no longer be going the route of Github Action to run terraform apply to build terraform project for each environment
2. Add buildspec.yml
3. configure-named-profile.sh?
4. install-terraform.sh
5. Call the ./shell/apply.sh



## Store Local Files/Cred
1. Create a python or shell scripts that extracts all the secret values from local credential files and 
sends it to Custom Dotnet Controller to store in AWS RDS PostgresSQL table
2. Create a python or shell script that retrives all the secret values from AWS RDS PostgresSQL table
and write back to original local file so that terraform doesn't throw an error
3. Create Dotnet Controller with GET and Post method
Each project should have it's own RDS table for unique column names as required by project.
Get -> Retrive secret value from RDS table
Post -> Store secret value from RDS table
AUTH -> Both(Get, Post) request types should have 
```sh
curl --request GET \
--url "https://api.insizon.com/terraform" \
--header "Authorization: Bearer <Github Classic Token>" \
--header "X-GitHub-Api-Version: 2022-11-28"
```
- Dotnet Controller - Get, Post
Both Get and Post request should extra the beaer token and then send post request to Github to verify that the token is valid
```sh
curl --request GET \
--url "https://api.github.com/octocat" \
--header "Authorization: Bearer <Github Classic Token>" \
--header "X-GitHub-Api-Version: 2022-11-28"
```
Ex. 
TableName - terraformAWS
terraformAWS column names may be
Id, lambdaCred, iamCred, beanstalk, ...etc
TableName - terraformAzure
terraformAzure colum name may be
Id, elantra, functionApp, webApp, ..etc


## Add new property to yaml files
1. Add a property named highestLevel or highestEnv for example that will not build the resource if not listed.
It's similar to create_service however highestLevel is target to specific environment bc some service I may only want created in lower environment
Ex. 
highestLevel: 
  - prod
  - qa
  - dev