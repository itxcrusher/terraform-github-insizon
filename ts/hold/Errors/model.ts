//Module
import { StatusCodeTypes } from "./type.js";




export interface ICustomError {
  Msg: string;
  StatusCodeType?: StatusCodeTypes;
  StatusCode?: number;
  ErrorCode?: number;
  ErrorCodeType?: string;
}