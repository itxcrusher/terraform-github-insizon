//Model
import { AWS_ApiVersionsEnum } from "../../../SaaS/Aws/CloudWatch/enum.js";
import { GlacierClient } from "@aws-sdk/client-glacier";





/**
 * @param Bucket_name - process.env.AWS_S3_Bucket
 * @param AWS_IAM_ServiceUser_AccessKeyId - process.env.AWS_IAM_ServiceUser_AccessKeyId
 * @param AWS_IAM_ServiceUser_SecretAccessKey - process.env.AWS_IAM_ServiceUser_SecretAccessKey
 */
export interface IAWS_Glacier_StorageCredential {
  isProd: string;
  Bucket_name?: string;
  Aws: {
    AWS_SecretManager_SecretName?: string;
    AWS_IAM_ServiceUser_AccessKeyId?: string;
    AWS_IAM_ServiceUser_SecretAccessKey?: string;
    Terraform_Service_Role_Name?: string;
  }
 }


/** 
 * @class AWS S3
 * @remarks
 * You don't need to close a 'connection", as there's no such thing as a 
 * continuous connection to S3 when using AmazonS3Client
 * @param region - The location of the AWS datacenter
 * @param accessKeyId - The AWS service acessKeyId
 * @param secretAccessKey - The AWS service secretAccessKey
 * @param apiVersion - THe api verion to lock into the correct apis
 * @returns 
 */
export interface IAWS_Glacier_Credentials {
  region: string;
  apiVersion: AWS_ApiVersionsEnum;
  credentials: {
    accessKeyId: string;
    secretAccessKey: string;
    sessionToken: string;
  }
}

// GlacierClient;
export interface IAws_Glacier_Setup_Output {
  Client: GlacierClient;
}


/**
 * @param vaultName - The name of the vault
 * @param accountId - The AccountId is the AWS Account ID. You can specify either the AWS Account ID or optionally a '-', 
 * in which case Amazon Glacier uses the AWS Account ID associated with the credentials used to sign the request.
 */
export interface IAWS_Glacier_Params {
  vaultName: string;
  accountId: "-";
}

/**
 * @param archiveDescription - The description for the data that will be uploaded
 * @param checksum -
 * @param body - The data that will be uploaded
 */
export interface IAWS_Glacier_Upload_Params extends IAWS_Glacier_Params {
  archiveDescription?: string;
  checksum?: string;
  body: string | Buffer;
}

/**
 * @param marker - A string used for pagination. The marker specifies the vault ARN after which the listing of vaults should begin.
 * @param limit - The maximum number of vaults to be returned. The default limit is 10. The number of vaults returned might be fewer than the specified limit, but the number of returned vaults never exceeds the limit.
 */
export interface IAWS_Glacier_List_Params extends IAWS_Glacier_Params {
  limit: number;
  marker?: string;
} 

/**
 * @param archiveId - The ID of the archive to delete.
 */
export interface IAWS_Glacier_DeleteArchive_Params extends IAWS_Glacier_Params {
  archiveId: string;
}


/**
 * @param metadata -
 * @param httpStatusCode - 200
 * @param requestId - 9321e2f9-327b-498b-8346-569976aa4de3
 * @param extendedRequestId - undefined
 * @param cfId - undefined
 * @param attempts -1
 * @param totalRetryDelay - 0
 * @param MessageId - 0100018c92beb66b-f00e0696-4808-4d73-a9e6-f296b50e5ed5-000000
 */
export interface IAWS_Glacier_Response {
  $metadata: {
    httpStatusCode?: number | any;
    requestId?: string | any;
    extendedRequestId?: undefined | any;
    cfId?: undefined | any;
    attempts?: number | any;
    totalRetryDelay?: number | any;
  }
}


/**
 * @param location - The URI of the vault that was created.
 */
export interface IAWS_Glacier_CreateVault_Response extends IAWS_Glacier_Response {
  location: string;
}

/**
 * @param location -
 * @param checksum -
 * @param archiveId -
 */
export interface IAWS_Glacier_Upload_Response extends IAWS_Glacier_Response {
  location: string;
  checksum: string;
  archiveId: string;
}



/**
 * @param Marker - The vault ARN at which to continue pagination of the results. You use the marker in another List Vaults request to obtain more vaults in the list.
 * @param VaultList - List of vaults.
 */
export interface IAWS_Glacier_ListVaults_Response extends IAWS_Glacier_Response {
  Marker: string;
  VaultList: Array<IAWS_Glacier_ListVaults_VaultList_Response>
}


/**
 * @param CreationDate - The Universal Coordinated Time (UTC) date when the vault was created. Ex. "2015-04-06T21:23:45.708Z"
 * @param LastInventoryDate - The Universal Coordinated Time (UTC) date when Amazon S3 Glacier completed the last vault inventory. Ex. "2015-04-07T00:26:19.028Z"
 * @param NumberOfArchives - The number of archives in the vault as of the last inventory date. This field will return null if an inventory has not yet run on the vault, for example if you just created the vault. Ex. 1
 * @param SizeInBytes - Total size, in bytes, of the archives in the vault as of the last inventory date. This field will return null if an inventory has not yet run on the vault, for example if you just created the vault. Ex. 3178496,
 * @param VaultARN -  The Amazon Resource Name (ARN) of the vault. List of vaults. "arn:aws:glacier:us-west-2:0123456789012:vaults/my-vault"
 * @param VaultName - The name of the vault
 */
interface IAWS_Glacier_ListVaults_VaultList_Response {
  CreationDate: string;
  LastInventoryDate: string;
  NumberOfArchives: number;
  SizeInBytes: number;
  VaultARN: string;
  VaultName: string;
}
