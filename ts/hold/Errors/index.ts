//Module
import { ICustomError } from "./model.js";
import { StatusCodeTypes } from "./type.js";


/**
 * @example 
 * throw new CustomError({Msg: 'Something went wrong', StatusCode: 500});
 * @note If you don't want to use CustomError use the built error object 
 * such as new Error(), new ReferenceError(), new SyntaxError(), new TypeError(), etc
 * @param Msg - 'Something went wrong'
 * @param StatusCode? - 
 * @param StatusCodeType? - 
 * @returns name - The class name. ex. CustomError
 * @link https://stackoverflow.com/questions/68258571/how-to-add-extension-function-to-express-response-in-typescript
 * @link https://engineering.udacity.com/handling-errors-like-a-pro-in-typescript-d7a314ad4991
 */
export class CustomError extends Error {

  //Property
  public msg?: string;
  public statusCode?: number;
  public statusCodeType?: StatusCodeTypes;
  public errorCode?: number;
  public errorCodeType?: string;

  constructor(props: ICustomError) {
    super(props.Msg);
    this.name = this.constructor.name;
    this.msg = props.Msg;
    this.statusCode = props.StatusCode;
    this.statusCodeType = props.StatusCodeType;
    this.errorCode = props.ErrorCode,
    this.errorCodeType = props.ErrorCodeType;
    Error.captureStackTrace(this, this.constructor);
  }
}