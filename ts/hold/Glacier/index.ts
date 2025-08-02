//Imports
import { PowerClassAwsSecretsManager, CustomError } from "@insizon/powerroute";
import { GlacierClient, ListVaultsCommand, UploadArchiveCommand, CreateVaultCommand, DeleteVaultCommand } from "@aws-sdk/client-glacier";
import { AWS_ApiVersionsEnum } from "../../../SaaS/Aws/CloudWatch/enum.js";
import { IAWS_Glacier_Params, IAWS_Glacier_Response, IAWS_Glacier_List_Params, IAWS_Glacier_Upload_Params, IAWS_Glacier_ListVaults_Response, IAWS_Glacier_Upload_Response, IAWS_Glacier_CreateVault_Response, IAWS_Glacier_DeleteArchive_Params, IAWS_Glacier_StorageCredential, IAws_Glacier_Setup_Output, IAWS_Glacier_Credentials } from "./model.js";




/**
 * @link - https://www.npmjs.com/package/@aws-sdk/client-glacier
 */
export class PowerClassAwsGlacier extends PowerClassAwsSecretsManager {

  //Property
  private cred: IAWS_Glacier_StorageCredential;

  constructor(cred: IAWS_Glacier_StorageCredential) {
    super({
      AWS_SecretManager_SecretName: cred.Aws.AWS_SecretManager_SecretName,
      AWS_IAM_ServiceUser_AccessKeyId: cred.Aws.AWS_IAM_ServiceUser_AccessKeyId,
      AWS_IAM_ServiceUser_SecretAccessKey: cred.Aws.AWS_IAM_ServiceUser_SecretAccessKey,
      Terraform_Service_Role_Name: cred.Aws.Terraform_Service_Role_Name
    });
    this.cred = cred;
  }

  private async setup(): Promise<IAws_Glacier_Setup_Output> {
    try {

      const roleCred = await this.getRoleCreds();
      const secret = await this.getAllSecretsTyped();
      if (!secret) throw new CustomError({Msg: "secret is undefined"});

      const AWS_IAM_ServiceUser_AccessKeyId = roleCred.AccessKeyId;
      const AWS_IAM_ServiceUser_SecretAccessKey = roleCred.SecretAccessKey;
      const AWS_IAM_ServiceUser_SessionToken = roleCred.SessionToken;

      if (!AWS_IAM_ServiceUser_AccessKeyId) {
        throw new CustomError({Msg: "AWS_IAM_ServiceUser_AccessKeyId is undefined"});
      } else if (!AWS_IAM_ServiceUser_SecretAccessKey) {
        throw new CustomError({Msg: "AWS_IAM_ServiceUser_SecretAccessKey is undefined"});
      } else if (AWS_IAM_ServiceUser_AccessKeyId === AWS_IAM_ServiceUser_SecretAccessKey) {
        throw new CustomError({Msg: "AWS_IAM_ServiceUser_AccessKeyId === AWS_IAM_ServiceUser_SecretAccessKey doesn't seem right"});
      } else if (!AWS_IAM_ServiceUser_SessionToken) {
        throw new CustomError({Msg: "AWS_IAM_ServiceUser_SessionToken is undefined"});
      }

      const Glacier_Config: IAWS_Glacier_Credentials = { 
        region: "us-east-2", 
        apiVersion: AWS_ApiVersionsEnum.Glacier, 
        credentials: { 
          accessKeyId: AWS_IAM_ServiceUser_AccessKeyId, 
          secretAccessKey: AWS_IAM_ServiceUser_SecretAccessKey,
          sessionToken: AWS_IAM_ServiceUser_SessionToken
      }};

      const client = new GlacierClient(Glacier_Config as any);

      return {
        Client: client
      }
    } catch(err) {
      console.log("What is setup error");
      throw err;
    }
  }

  /**
   * Func to create a AWS Glacier vault
   * @param vaultName -
   * @returns 
   */
  async createVault(vaultName: string = "myVault") {
    try {
      const setupAuth = await this.setup();

      const params: IAWS_Glacier_Params = {
        vaultName: vaultName,
        accountId: "-"
      }
  
      const command = new CreateVaultCommand(params);
      const response = await setupAuth.Client.send(command) as IAWS_Glacier_CreateVault_Response;
      
      return response;
    } catch(err) {
        console.log("What is createVault err", err);
        throw err;
    }
  }

  /**
   * Func to upload files or data to glacier vault
   * @param vaultName - 
   * @param body -
   * @param description -
   * @returns 
   */
  async uploadToGlacier(vaultName: string = "myVault", body: string | Buffer, description: string = "My dogs are great") {
    try {
      const setupAuth = await this.setup();

      const params: IAWS_Glacier_Upload_Params= { 
        vaultName: vaultName,
        accountId: "-",
        body: body,
        archiveDescription: description
      };

      const command = new UploadArchiveCommand(params);
      const response = await setupAuth.Client.send(command) as IAWS_Glacier_Upload_Response;
      
      return response;
    } catch(err) {
        console.log("What is uploadToGlacier err", err);
        throw err;
    }
  }

  /**
   * Func to list all glacier vaults
   * @param vaultName -
   * @param limit -
   */
  async listGlacierVaults(vaultName: string = "myVault", limit: number = 10) {
    try {

      const setupAuth = await this.setup();

      const params: IAWS_Glacier_List_Params= { 
        vaultName: vaultName,
        accountId: "-",
        limit: limit
      };

      const command = new ListVaultsCommand(params);
      const response = await setupAuth.Client.send(command) as IAWS_Glacier_ListVaults_Response;
      
      return response;
    } catch(err) {
        console.log("What is listGlacierVaults err", err);
        throw err;
    }
  }

  /**
   * Func to delete a glacier vault
   * @param vaultName 
   * @returns 
   */
  async deleteVault(vaultName: string = "myVault") {
    try {
      const setupAuth = await this.setup();

      const params: IAWS_Glacier_Params= { 
        vaultName: vaultName,
        accountId: "-",
      };

      const command = new DeleteVaultCommand(params)
      const response = await setupAuth.Client.send(command) as IAWS_Glacier_Response;
      
      return response;
    } catch(err) {
        console.log("What is deleteVault err", err);
        throw err;
    }
  }

  /**
   * Func to delete a vault archived
   * @param vaultName 
   * @param archiveId - The item in vault that will be deleted.
   * @returns 
   */
  async deleteArchived(vaultName: string = "myVault", archiveId: string) {
    try {
      const setupAuth = await this.setup();

      const params: IAWS_Glacier_DeleteArchive_Params= { 
        vaultName: vaultName,
        accountId: "-",
        archiveId: archiveId
      };

      const command = new DeleteVaultCommand(params)
      const response = await setupAuth.Client.send(command) as IAWS_Glacier_Response;
      
      return response;
    } catch(err) {
        console.log("What is deleteArchived err", err);
        throw err;
    }
  }
}