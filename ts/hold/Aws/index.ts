//Imports
import {CustomError, PowerClassAwsSecretsManager, PowerRandom} from "@insizon/powerroute";
import {SNSClient, PublishCommand, CheckIfPhoneNumberIsOptedOutCommand, OptInPhoneNumberCommand} from "@aws-sdk/client-sns";
import {IAWS_SNS_Phone_Params, IAWS_SNS_Phone_CheckIfOptedIn_Params, IAWS_SNS_Phone_CheckIfOptedOut_Response, IAWS_SNS_Phone_OptInNumber_Response, IAWS_SNS_Phone_OptInPhoneNumber_Params,
IAWS_SNS_Phone_Response, IAWS_Credentials_AwsSns, IAwsSns_SMS_Credentials, IAwsSns_SMS_smsphoneOTP, IAwsSns_SMS_sendMultipleTxt, IAwsSns_SMS_OptInPhoneNumber, IAwsSns_SMS_checkIfPhoneNumberIsOptedOut} from "./model.js";







/**
 * Func to send message to users phone number
 * @link
 * @link https://www.npmjs.com/package/@aws-sdk/client-sns
 */
export class PowerClassAwsSNS extends PowerClassAwsSecretsManager {

    //Singleton
  // public static instance = new PowerClassAwsSNS();

  //Properties
  private cred: IAwsSns_SMS_Credentials;

  constructor(cred: IAwsSns_SMS_Credentials) {
    super({
      AWS_SecretManager_SecretName: cred.Aws.AWS_SecretManager_SecretName,
      AWS_IAM_ServiceUser_AccessKeyId: cred.Aws.AWS_IAM_ServiceUser_AccessKeyId,
      AWS_IAM_ServiceUser_SecretAccessKey: cred.Aws.AWS_IAM_ServiceUser_SecretAccessKey,
      Terraform_Service_Role_Name: cred.Aws.Terraform_Service_Role_Name
    });
    this.cred = cred;
  }


  private async setup() {
    try {

      const roleCred = await this.getRoleCreds();
      const secret = await this.getAllSecretsTyped();
      if (!secret) throw new CustomError({Msg: "secret is undefined"});

      const AWS_IAM_ServiceUser_AccessKeyId = roleCred.AccessKeyId;
      const AWS_IAM_ServiceUser_SecretAccessKey = roleCred.SecretAccessKey;
      const AWS_IAM_ServiceUser_SessionToken = roleCred.SessionToken;
      const AWS_SNS_TollFreeNumber = this.cred.Defaults.AWS_SNS_TollFreeNumber ? this.cred.Defaults.AWS_SNS_TollFreeNumber : secret.SecretAsObject.AWS.AWS_SNS_TollFreeNumber;
      const AWS_SNS_DefaultNumber = this.cred.Defaults.AWS_SNS_DefaultNumber ? this.cred.Defaults.AWS_SNS_DefaultNumber : secret.SecretAsObject.AWS.AWS_SNS_DefaultNumber;

      if (!AWS_IAM_ServiceUser_AccessKeyId) {
        throw new CustomError({Msg: "AWS_IAM_ServiceUser_AccessKeyId is undefined"});
      } else if (!AWS_IAM_ServiceUser_SecretAccessKey) {
        throw new CustomError({Msg: "AWS_IAM_ServiceUser_SecretAccessKey is undefined"});
      } else if (AWS_IAM_ServiceUser_AccessKeyId === AWS_IAM_ServiceUser_SecretAccessKey) {
        throw new CustomError({Msg: "AWS_IAM_ServiceUser_AccessKeyId === AWS_IAM_ServiceUser_SecretAccessKey seems incorrect"});
      } else if (!AWS_SNS_TollFreeNumber) {
        throw new CustomError({Msg: "AWS_SNS_TollFreeNumber is undefined"});
      } else if (!AWS_SNS_DefaultNumber) {
        throw new CustomError({Msg: "AWS_SNS_DefaultNumber is undefined"});
      } else if (!this.cred.Defaults.AppName) {
        throw new CustomError({Msg: "this.cred.Defaults.AppName is undefined"});
      } else if (!AWS_IAM_ServiceUser_SessionToken) {
        throw new CustomError({Msg: "AWS_IAM_ServiceUser_SessionToken is undefined"});
      }

      const SES_CONFIG: IAWS_Credentials_AwsSns = { 
        region: "us-east-2", 
        apiVersion: "2010-03-31",
        credentials: { 
          accessKeyId: AWS_IAM_ServiceUser_AccessKeyId, 
          secretAccessKey: AWS_IAM_ServiceUser_SecretAccessKey,
          sessionToken: AWS_IAM_ServiceUser_SessionToken
      }};

      const client = new SNSClient(SES_CONFIG as any);

      return {
        Client: client,
        Defaults: {
          isProd: this.cred.Defaults.isProd as string,
          AWS_SNS_TollFreeNumber: AWS_SNS_TollFreeNumber,
          AWS_SNS_DefaultNumber: AWS_SNS_DefaultNumber
        }
      }

    } catch(err) {
      console.log("What is setup err");
      throw err;
    }
  }
  /**
   * Func to send a message to a users
   * @param mobileNo - The number that you want to send message to.
   * @returns 
   */
  async sms_phoneOTP(props: IAwsSns_SMS_smsphoneOTP) {
      try {

        const setupAuth = await this.setup();

        if (!props.recipientMobileNumber) throw new CustomError({Msg: "recipientMobileNumber is undefined"});
        const OTP = PowerRandom.generateRandomNumber(1000, 9999);
        const isNumber = parseInt(props.recipientMobileNumber) ? parseInt(props.recipientMobileNumber) : false;
        if (isNumber === false) throw new CustomError({Msg: "Not a valid number"});
      
        const params: IAWS_SNS_Phone_Params = {
          Subject: "OTP",
          Message: props.IsOTP_Message ?
           `Your ${this.cred.Defaults.AppName} verification code is ${OTP}. For security reasons do not use this code outside of the ${this.cred.Defaults.AppName} app. Do not sure this code with anyone.`
           : props.Message,
          PhoneNumber: props.recipientMobileNumber,
          MessageAttributes: {
            "AWS.MM.SMS.OriginationNumber": {
              DataType: "String",
              StringValue: setupAuth.Defaults.AWS_SNS_TollFreeNumber
            },
            "AWS.SNS.SMS.SMSType": {
              DataType: "String",
              StringValue: "Transactional"
            }
           }
        };
      
        const command = new PublishCommand(params as any);
        const response = await setupAuth.Client.send(command) as IAWS_SNS_Phone_Response;
        
        return {
          Response: response,
          OTP: OTP,
          Message: params.Message
        }
    } catch(err) {
        console.log("What is phoneOTP err", err);
        throw err;
    }
  }

  /**
   * Will loop through your list and make a new request for each numbe
   * @remarks
   * This func should be wrapped in a forloop or loop to iterate over all phone numbers.
   * @param recipientMobileNumber - The user phone number that will recieve text message.
   * @param msg - The msg that will be sent to users. Ex. Maybe send msg letting users know about new update.
   */
  async sendMultipleTxt(props: IAwsSns_SMS_sendMultipleTxt) {
      try {

        const setupAuth = await this.setup();

        if (!props.RecipientMobileNumber) throw new CustomError({Msg: "recipientMobileNumber is undefined"});
        const isNumber = parseInt(props.RecipientMobileNumber) ? parseInt(props.RecipientMobileNumber) : false;
        if (isNumber === false) throw new CustomError({Msg: "Not a valid number"});

        const params: IAWS_SNS_Phone_Params = {
          Subject: "OTP",
          Message: `${this.cred.Defaults.AppName} here. ${props.Message}`,
          PhoneNumber: props.RecipientMobileNumber,
          MessageAttributes: {
            "AWS.MM.SMS.OriginationNumber": {
              DataType: "String",
              StringValue: setupAuth.Defaults.AWS_SNS_TollFreeNumber
            },
            "AWS.SNS.SMS.SMSType": {
              DataType: "String",
              StringValue: "Transactional"
            }
          }
        };
      
        const command = new PublishCommand(params as any);
        const response = await setupAuth.Client.send(command) as IAWS_SNS_Phone_Response;
        
        return {
          Response: response,
          Message: params.Message
        }
    } catch(err) {
        console.log("What is sendMultipleTxt err");
        throw err;
    }
  }


  /**
   * Func to opt in a user phone number.
   * @param phoneNumber - The user phone number
   * @returns 
   */
  async OptInPhoneNumber(props: IAwsSns_SMS_OptInPhoneNumber) {
    try {

        const setupAuth = await this.setup();

        if (!props.RecipientMobileNumber) throw new CustomError({Msg: "recipientMobileNumber is undefined"});
        const isNumber = parseInt(props.RecipientMobileNumber) ? parseInt(props.RecipientMobileNumber) : false;
        if (isNumber === false) throw new CustomError({Msg: "Not a valid number"});

        const params: IAWS_SNS_Phone_OptInPhoneNumber_Params = {
          phoneNumber: props.RecipientMobileNumber,
        }
      
        const command = new OptInPhoneNumberCommand(params)
        const response = await setupAuth.Client.send(command) as IAWS_SNS_Phone_OptInNumber_Response;
        
        return {
          Response: response,
          To: params.phoneNumber
        }
    } catch(err) {
        console.log("What is optInPhoneNumber err");
        throw err;
    }
  }

  /**
   * Func to check if phone number is opted out.
   * @param phoneNumber - The phone number that will be check if user opted in to sns text.
   */
  async checkIfPhoneNumberIsOptedOut(props: IAwsSns_SMS_checkIfPhoneNumberIsOptedOut) {
    try {

        const setupAuth = await this.setup();

        if (!props.RecipientMobileNumber) throw new CustomError({Msg: "recipientMobileNumber is undefined"});
        const isNumber = parseInt(props.RecipientMobileNumber) ? parseInt(props.RecipientMobileNumber) : false;
        if (isNumber === false) throw new CustomError({Msg: "Not a valid number"});

        const params: IAWS_SNS_Phone_CheckIfOptedIn_Params = {
          phoneNumber: props.RecipientMobileNumber,
        }
      
        const command = new CheckIfPhoneNumberIsOptedOutCommand(params);
        const response = await setupAuth.Client.send(command) as IAWS_SNS_Phone_CheckIfOptedOut_Response;
        
        return {
          Response: response,
          To: params.phoneNumber
        }
    } catch(err) {
        console.log("What is checkIfPhoneNumberIsOptedOut err", err);
        throw err;
    }
  }

}
