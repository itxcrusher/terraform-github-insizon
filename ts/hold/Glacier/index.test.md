//Module
import * as vitest from 'vitest';
import { PowerClassAwsS3 } from '../index_export';
import { TestTimeout, clearnUp, testfileName_Txt } from '../../../../../test/defaults';
import { GetMimeType } from '../../../../../test/util_func';



/**
 * npm install --save-dev aws-sdk-client-mock
 * @param
 * 
 */
vitest.describe("PowerClassAwsS3", () => {

  //Variables
  const testFileObj = GetMimeType(testfileName_Txt);
  let powerStorageAwsS3: PowerClassAwsS3;

  //Runs before all the test
  vitest.beforeAll(() => {
    //Configure S3 client with your actual credentials and region
    powerStorageAwsS3 = new PowerClassAwsS3({
      isProd: "false",
      AWS_S3_Bucket: process.env.AWS_S3_Bucket,
      Aws: {
        AWS_SecretManager_SecretName: process.env.AWS_SecretManager_SecretName,
        AWS_IAM_ServiceUser_AccessKeyId: process.env.AWS_IAM_ServiceUser_AccessKeyId,
        AWS_IAM_ServiceUser_SecretAccessKey: process.env.AWS_IAM_ServiceUser_SecretAccessKey,
        Terraform_Service_Role_Name: process.env.Terraform_Service_Role_Name,
        AWS_Cloudfront_Private_Key: process.env.AWS_Cloudfront_Private_Key,
        AWS_CloudFront_KeyPairId: process.env.AWS_CloudFront_KeyPairId,
        AWS_Cloudfront_DistributionSubdomain: process.env.AWS_Cloudfront_DistributionSubdomain
      }
    });
  });

  if (clearnUp) {
    //Run after all the test for clearnUp
    vitest.afterAll(async () => {
      // Clean up the test object after all tests
      await powerStorageAwsS3.deleteImage({
        ImageName: testFileObj.fileName
      });
    });
  }

  //.test aka .it - A test case that will be tested
  vitest.it('Should upload a file to AwsS3 bucket', async () => {
    
    //Verify no error is throw uploading file
    vitest.expect(async () => {
      // Upload the test file
      const uploadResponse = await powerStorageAwsS3.uploadImageS3({
        imgBuffer: testFileObj.fileBuffer,
        mimeType: testFileObj.mimeType,
        FileExtension: testFileObj.FileExtension,
        fileNameOverride: testFileObj.fileName
      });

      console.log(uploadResponse);
    }).not.throw();

  }, TestTimeout.Sec_30);



  vitest.it('Should retrive file from AwsS3 bucket', async () => {

    // Retrieve the uploaded file
    const uploadResponse = await powerStorageAwsS3.getSingleSignedCloudFrontImg({
      FileNameAssignedS3: testFileObj.fileName
    });

     console.log("what is output of getSingleCloudFrontImg", uploadResponse);
    
    // // Verify the content
    const uploadedContent = uploadResponse.PresignedURL;
    vitest.expect(uploadedContent).not.toBeNull();
  }, TestTimeout.Sec_30);
})
