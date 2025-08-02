//Model
import { INodeMailer_FromNameTypes } from "../../Email_Protocol/1.SMTP/Nodemailer/type.js";
import { AWS_ApiVersionsEnum } from "../../SaaS/Aws/CloudWatch/enum.js";



/**
 * @param isProd - process.env.isProduction
 * @param tollFreeNumber - process.env.AWS_SNS_TollFreeNumber;
 * @param defaultNumber - process.env.AWS_SNS_DefaultNumber;
 */
export interface IAwsSns_SMS_Credentials {
  Defaults: {
    isProd?: string;
    AppName: INodeMailer_FromNameTypes;
    AWS_SNS_TollFreeNumber?: string;
    AWS_SNS_DefaultNumber?: string;
  }
  Aws: {
    AWS_SecretManager_SecretName?: string;
    AWS_IAM_ServiceUser_AccessKeyId?: string;
    AWS_IAM_ServiceUser_SecretAccessKey?: string;
    Terraform_Service_Role_Name?: string;
  }
}




export interface IAwsSns_SMS_smsphoneOTP {
  recipientMobileNumber: string;
  IsOTP_Message?: boolean;
  Message: string;
}


export interface IAwsSns_SMS_sendMultipleTxt {
  RecipientMobileNumber: string; 
  Message: string;
}


export interface IAwsSns_SMS_OptInPhoneNumber {
  RecipientMobileNumber: string;
}


export interface IAwsSns_SMS_checkIfPhoneNumberIsOptedOut {
  RecipientMobileNumber: string;
}

/**
 * @param PhoneNumber - The phone number to which you want to deliver an SMS message. If you don't specify a value for the PhoneNumber parameter, you must specify a value for the TargetArn or TopicArn parameters.
 * @param Message - The message you want to send.
 * @param Subject - Optional parameter to be used as the "Subject" line when the message is delivered to email endpoints. This field will also be included, if present, in the standard JSON messages delivered to other endpoints.
 * @param MessageAttributes - Message attributes for Publish action.
 * @param MessageStructure -Set MessageStructure to json if you want to send a different message for each protocol
 * @param TopicArn - The topic you want to publish to. If you don't specify a value for the TopicArn parameter, you must specify a value for the PhoneNumber or TargetArn parameters.
 * @param TargetArn - If you don't specify a value for the TargetArn parameter, you must specify a value for the PhoneNumber or TopicArn parameters.
 * @param MessageDeduplicationId - This parameter applies only to FIFO (first-in-first-out) topics. Every message must have a unique MessageDeduplicationId, which is a token used for deduplication of sent messages
 * @param MessageGroupId - This parameter applies only to FIFO (first-in-first-out) topics. The MessageGroupId is a tag that specifies that a message belongs to a specific message group.
 * @link https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/client/sns/command/PublishCommand/
 */
export interface IAWS_SNS_Phone_Params {
  PhoneNumber: string;
  Message: string;
  Subject: string;
  MessageAttributes: ISNS_Phone_MsgAtrribute;
  TopicArn?: string;
  TargetArn?: string;
  MessageStructure?: "json";
  MessageDeduplicationId?: string;
  MessageGroupId?: string;
}


/**
 * @param phoneNumber - The phone number that will be checked to see if the user opted in.
 */
export interface IAWS_SNS_Phone_CheckIfOptedIn_Params {
  phoneNumber: string;
}


/**
 * @param phoneNumber - The users phone number that will be opted in.
 */
export interface IAWS_SNS_Phone_OptInPhoneNumber_Params {
  phoneNumber: string;
}


/**
 * @link https://docs.aws.amazon.com/sns/latest/dg/sns-message-attributes.html
 * @link https://stackoverflow.com/questions/52683927/how-to-change-sms-type-with-aws-sns-publish
 * @link https://stackoverflow.com/questions/67573881/can-you-specify-origination-number-on-sms-send-aws-sdk-js
 */
interface ISNS_Phone_MsgAtrribute {
  "AWS.MM.SMS.OriginationNumber":  ISNS_Phone_MsgAtrribute_OriginatingNumber;
  "AWS.SNS.SMS.SMSType": ISNS_Phone_MsgAtrribute_SmsType;
  "AWS.SNS.SMS.SenderID"?: ISNS_Phone_MsgAtrribute_SenderID;
} 

/**
 * @param <key> - MessageAttributeValue
 * @param DataType - Amazon SNS supports the following logical data types: String, String.Array, Number, and Binary. 
 * @param StringValue - The toll free number or phone number that will be used to send message;
 */
interface ISNS_Phone_MsgAtrribute_OriginatingNumber {
    DataType: "String" | "String.Array" | "Number" | "Binary";
    StringValue: string;
}

/**
 * interface for setting either if message will be of type tranactional or promotional
 * @param <key> - MessageAttributeValue
 * @param DataType - Amazon SNS supports the following logical data types: String, String.Array, Number, and Binary. 
 * @param StringValue - Strings are Unicode with UTF8 binary encoding
 */
interface ISNS_Phone_MsgAtrribute_SmsType {
  DataType: "String" | "String.Array" | "Number" | "Binary";
  StringValue: "Transactional" | "Promotional";
}

/**
 * interface If you plan to send messages to recipients a country where sender IDs are required, you can request a sender ID 
 * @param <key> - MessageAttributeValue
 * @param DataType - Amazon SNS supports the following logical data types: String, String.Array, Number, and Binary. 
 * @param StringValue - Strings are Unicode with UTF8 binary encoding
 */
interface ISNS_Phone_MsgAtrribute_SenderID {
  DataType: "String" | "String.Array" | "Number" | "Binary";
  StringValue: string;
}

type MsgAttributeFullExtra = "AWS.MM.SMS.OriginationNumber" | "AWS.SNS.SMS.MaxPrice" | "AWS.SNS.SMS.SMSType" | "AWS.MM.SMS.EntityId" | "AWS.MM.SMS.TemplateId";


/**
 * @param MessageId -Unique identifier assigned to the published message. Length Constraint: Maximum 100 characters
 * @param SequenceNumber -This response element applies only to FIFO (first-in-first-out) topics.
 * @link This response element applies only to FIFO (first-in-first-out) topics.
 */
export interface  IAWS_SNS_Phone_Response extends IAWS_SNS_Phone_Metadata {
  MessageId: string;
  SequenceNumber: string;
}

/**
 * @param isOptedOut - Indicates whether the phone number is opted out. true – The phone number is opted out, meaning you cannot publish SMS messages to it.
 * false – The phone number is opted in, meaning you can publish SMS messages to it.
 */
export interface IAWS_SNS_Phone_CheckIfOptedOut_Response extends IAWS_SNS_Phone_Metadata {
  isOptedOut: boolean;
}

export interface IAWS_SNS_Phone_OptInNumber_Response extends IAWS_SNS_Phone_Metadata {}


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
interface IAWS_SNS_Phone_Metadata {
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
export interface IAWS_Credentials_AwsSns {
  region: string;
  apiVersion: AWS_ApiVersionsEnum;
  credentials: {
    accessKeyId: string;
    secretAccessKey: string;
    sessionToken: string;
  }
}
