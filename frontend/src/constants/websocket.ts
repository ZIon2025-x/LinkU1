/**
 * WebSocket关闭码协议契约（必须与后端一致）
 * 所有关闭码和reason必须使用此文件中的常量，禁止硬编码
 * 修改关闭码/reason需要前后端同步更新
 */

// WebSocket关闭码协议契约（必须与后端一致）
export const WS_CLOSE_CODE_NORMAL = 1000;  // 正常关闭（仅用于"新连接替换"）
export const WS_CLOSE_CODE_HEARTBEAT_TIMEOUT = 4001;  // 心跳超时（需要重连）
export const WS_CLOSE_CODE_AUTH_FAILED = 1008;  // 认证失败

// 关闭原因（固定文案，禁止修改）
export const WS_CLOSE_REASON_NEW_CONNECTION = "New connection established"; // 新连接替换，前端不重连
export const WS_CLOSE_REASON_HEARTBEAT_TIMEOUT = "Heartbeat timeout"; // 心跳超时，前端需要重连
export const WS_CLOSE_REASON_AUTH_FAILED = "Authentication failed";
export const WS_CLOSE_REASON_TOKEN_EXPIRED = "Token expired";
export const WS_CLOSE_REASON_TOKEN_INVALID = "Token invalid";

