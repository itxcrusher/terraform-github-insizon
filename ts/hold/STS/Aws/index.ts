//Module
import { STSClient, AssumeRoleCommand, GetCallerIdentityCommand } from "@aws-sdk/client-sts";
import { IAWS_STS_Credentials } from "./model.js";





/**
 * STSCliet - Security Token Service (STS) enables you to request temporary, limited-privileges credentials for users.
 * @note - Used when you want to use Role policies
 * @link https://www.youtube.com/watch?v=dqF4VJCska4
 */
export class PowerClassAwsSTS {

  //properties
  private credSts: IAWS_STS_Credentials;

  constructor(credSts: IAWS_STS_Credentials) {
    this.credSts = credSts;
  }


  /**
   * @param Terraform_Service_Role_Name - Terrafrom creates this role
   */
  private async setupSts() {
    try {


      console.log("What is this.credSts - ", this.credSts);

      if (!this.credSts.AWS_IAM_ServiceUser_AccessKeyId) {
        throw "this.credSts.AWS_IAM_ServiceUser_AccessKeyId is undefined";
      } else if (!this.credSts.AWS_IAM_ServiceUser_SecretAccessKey) {
        throw "this.credSts.AWS_IAM_ServiceUser_SecretAccessKey is undefined";
      } else if (this.credSts.AWS_IAM_ServiceUser_AccessKeyId === this.credSts.AWS_IAM_ServiceUser_SecretAccessKey) {
        throw "this.credSts.AWS_IAM_ServiceUser_AccessKeyId === this.credSts.AWS_IAM_ServiceUser_SecretAccessKey doesn't seem right";
      } else if (!this.credSts.Terraform_Service_Role_Name) {
        throw "this.credSts.Terraform_Service_Role_Name is undefined";
      }

      /* 2. Use user creds to call STS */
      const sts = new STSClient({
        region: "us-east-2",
        credentials: {
          accessKeyId: this.credSts.AWS_IAM_ServiceUser_AccessKeyId,
          secretAccessKey: this.credSts.AWS_IAM_ServiceUser_SecretAccessKey,
        },
      });


      return {
        Client: sts,
        Creds: {
          Terraform_Service_Role_Name: this.credSts.Terraform_Service_Role_Name
        }
      }

    } catch(err) {
      console.log("What is setupSts err");
      throw err;
    }
  }

  /**
   * Needed to assign role policies to accounts
   * @returns 
   */
  async getRoleCreds() {
    try {

        const sts = await this.setupSts();

        /* 3. Discover account ID */
        const idResp = await sts.Client.send(new GetCallerIdentityCommand({}));
        const accountId = idResp.Account;
        if (!accountId) {
          throw new Error("Unable to determine AWS account ID");
        }

        /* 4. Assume the serviceAccount role */
        const assumeResp = await sts.Client.send(
          new AssumeRoleCommand({
            RoleArn: `arn:aws:iam::${accountId}:role/${sts.Creds.Terraform_Service_Role_Name}`,
            RoleSessionName: "insizon-app-sessionn",
            DurationSeconds: 3600,
          })
        );

        const roleCreds = assumeResp.Credentials;
        if (!roleCreds) {
          throw new Error("AssumeRole returned no credentials");
        }

        return roleCreds;

    } catch(err) {
      console.log("What is getRoleCreds err");
      throw err;
    }
  }
}