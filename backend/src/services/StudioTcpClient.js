/**
 * StudioTcpClient — Roblox Studio Plugin과 직접 TCP 통신
 *
 * Studio MCP 중계 서버(rbxBStudio-mcp)를 거치지 않고
 * 백엔드에서 직접 Roblox Studio Plugin (포트 44755)과 통신
 *
 * 프로토콜:
 * - GET  /request  — 대기 중인 명령 요청 (long polling)
 * - POST /response — 실행 결과 전송
 * - POST /proxy    — 대체 경로로 명령 전송
 */

const http = require("http");

// ─── 설정 ─────────────────────────────────────────────────────────────
const CONFIG = {
    host: "127.0.0.1",
    port: 44755,
    longPollTimeout: 15000, // 15초 (Studio MCP와 동일)
    requestTimeout: 20000,  // 전체 요청 타임아웃
    maxRetries: 3,
    retryDelay: 1000,
};

// ─── HTTP 요청 헬퍼 (Promise wrapper) ─────────────────────────────────
function makeRequest(options, body = null) {
    return new Promise((resolve, reject) => {
        const req = http.request(options, (res) => {
            let data = "";

            res.on("data", (chunk) => {
                data += chunk;
            });

            res.on("end", () => {
                try {
                    if (res.statusCode === 204) {
                        // No Content - Studio가 준비 중 (long polling timeout)
                        resolve(null);
                    } else if (res.statusCode >= 200 && res.statusCode < 300) {
                        resolve(data ? JSON.parse(data) : null);
                    } else if (res.statusCode === 423) {
                        // Locked - long polling timeout (Studio MCP가 423 대신 204 사용 가능)
                        resolve(null);
                    } else {
                        reject(new Error(`HTTP ${res.statusCode}: ${data}`));
                    }
                } catch (e) {
                    reject(new Error(`JSON 파싱 실패: ${e.message}`));
                }
            });
        });

        req.on("error", (error) => {
            reject(error);
        });

        req.on("timeout", () => {
            req.destroy();
            reject(new Error(`요청 타임아웃: ${options.path}`));
        });

        req.setTimeout(CONFIG.requestTimeout);

        if (body) {
            req.write(body);
        }

        req.end();
    });
}

// ─── UUID 생성 헬퍼 ─────────────────────────────────────────────────────
function generateUUID() {
    return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
        const r = (Math.random() * 16) | 0;
        const v = c === "x" ? r : (r & 0x3) | 0x8;
        return v.toString(16);
    });
}

// ─── 메인 클래스: StudioTcpClient ───────────────────────────────────────
class StudioTcpClient {
    constructor(options = {}) {
        this.host = options.host || CONFIG.host;
        this.port = options.port || CONFIG.port;
        this.debug = options.debug || false;
    }

    _log(...args) {
        if (this.debug) {
            console.log("[StudioTcpClient]", ...args);
        }
    }

    /**
     * 연결 상태 확인
     * Studio MCP는 /status 엔드포인트가 없으므로
     * /request를 짧은 타임아웃으로 호출하여 연결 확인
     * @returns {Promise<{connected: boolean, error?: string}>}
     */
    async getStatus() {
        const options = {
            hostname: this.host,
            port: this.port,
            path: "/request",
            method: "GET",
        };

        // 짧은 타임아웃으로 연결만 확인
        const shortTimeoutOptions = {
            ...options,
            timeout: 2000, // 2초만 대기
        };

        try {
            // 타임아웃이나 응답이 있으면 연결된 것으로 간주
            await Promise.race([
                makeRequest(shortTimeoutOptions),
                new Promise((_, reject) =>
                    setTimeout(() => reject(new Error("timeout")), 2500)
                ),
            ]);
            return { connected: true };
        } catch (error) {
            // ECONNREFUSED는 Studio가 실행 중이 아님
            if (error.code === "ECONNREFUSED" || error.message.includes("ECONNREFUSED")) {
                return {
                    connected: false,
                    error: "Roblox Studio가 실행 중이지 않습니다",
                };
            }
            // 타임아웃은 연결됨 (long polling 정상 동작)
            if (error.message === "timeout") {
                return { connected: true };
            }
            return {
                connected: false,
                error: error.message,
            };
        }
    }

    /**
     * Studio에서 대기 중인 요청 확인 (long polling)
     * Studio가 준비될 때까지 최대 30초 대기
     * @returns {Promise<{id: string, args: object}|null>}
     */
    async _getRequest() {
        const maxWaitTime = 30000; // 30초
        const startTime = Date.now();
        let attempt = 0;

        while (Date.now() - startTime < maxWaitTime) {
            attempt++;
            this._log(`_getRequest attempt ${attempt}...`);

            const options = {
                hostname: this.host,
                port: this.port,
                path: "/request",
                method: "GET",
                timeout: 3000, // 짧은 타임아웃으로 빠른 재시도
            };

            try {
                const result = await makeRequest(options);
                if (result && result.id) {
                    this._log("Request result:", result);
                    return result;
                }
                // null이면 Studio가 아직 요청을 보내지 않음
                this._log("No request yet, retrying...");
            } catch (error) {
                // 타임아웃이나 연결 거부는 재시도
                this._log("Request error:", error.message);
            }

            // 재시도 전 대기
            await new Promise((r) => setTimeout(r, 500));
        }

        throw new Error("Studio가 준비되지 않았습니다. Plugin이 활성화되어 있는지 확인하세요.");
    }

    /**
     * 실행 결과 전송
     * @param {string} id - 요청 ID
     * @param {string} response - 실행 결과 문자열
     * @returns {Promise<void>}
     */
    async _sendResponse(id, response) {
        const payload = {
            id,
            response,
        };

        const options = {
            hostname: this.host,
            port: this.port,
            path: "/response",
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
        };

        return makeRequest(options, JSON.stringify(payload));
    }

    /**
     * Lua 코드 실행 (proxy 엔드포인트 사용)
     * @param {string} code - 실행할 Lua 코드
     * @returns {Promise<string>} 실행 결과 (print 출력)
     */
    async runCode(code) {
        this._log("runCode 요청:", code.substring(0, 50) + "...");

        // proxy 엔드포인트를 사용하여 직접 명령 전송
        const commandPayload = {
            id: generateUUID(),
            args: {
                RunCode: {
                    command: code,
                },
            },
        };

        return this.proxyCommand(commandPayload);
    }

    /**
     * 모델 삽입 (proxy 엔드포인트 사용)
     * @param {string} query - 모델 검색어
     * @returns {Promise<string>} 삽입된 모델 이름
     */
    async insertModel(query) {
        this._log("insertModel 요청:", query);

        // proxy 엔드포인트를 사용하여 직접 명령 전송
        const commandPayload = {
            id: generateUUID(),
            args: {
                InsertModel: {
                    query,
                },
            },
        };

        return this.proxyCommand(commandPayload);
    }

    /**
     * Proxy 엔드포인트 사용 (대체 경로)
     * @param {object} command - 명령 객체
     * @returns {Promise<string>} 응답의 response 필드
     */
    async proxyCommand(command) {
        this._log("proxyCommand 요청:", command);

        const id = command.id || generateUUID();
        const payload = {
            ...command,
            id,
        };

        const options = {
            hostname: this.host,
            port: this.port,
            path: "/proxy",
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
        };

        try {
            const responseData = await makeRequest(options, JSON.stringify(payload));
            this._log("proxyCommand 응답:", responseData);

            // response 필드 반환
            if (responseData && responseData.response !== undefined) {
                return responseData.response;
            }

            return JSON.stringify(responseData);
        } catch (error) {
            this._log("proxyCommand 실패:", error.message);
            throw error;
        }
    }

    /**
     * 대화형 세션 - 여러 명령을 순차적으로 실행
     * @param {Array<{code: string}>} commands - 명령 배열
     * @returns {Promise<Array<string>>} 각 명령의 결과
     */
    async runBatch(commands) {
        const results = [];

        for (const cmd of commands) {
            try {
                const result = await this.runCode(cmd.code);
                results.push({ success: true, output: result });
            } catch (error) {
                results.push({ success: false, error: error.message });
            }
        }

        return results;
    }
}

// ─── 싱글톤 인스턴스 ───────────────────────────────────────────────────
let clientInstance = null;

/**
 * Studio TCP 클라이언트 싱글톤 가져오기
 * @param {object} options - 설정 옵션 (기존 인스턴스 업데이트에 사용)
 * @returns {StudioTcpClient}
 */
function getClient(options = {}) {
    if (!clientInstance) {
        clientInstance = new StudioTcpClient(options);
    } else if (options.debug !== undefined) {
        // 기존 인스턴스의 debug 옵션 업데이트
        clientInstance.debug = options.debug;
    }
    return clientInstance;
}

// ─── Express 미들웨어: 연결 상태 확인 ───────────────────────────────────
function connectionCheckMiddleware(req, res, next) {
    const client = getClient();

    client.getStatus()
        .then((status) => {
            req.studioConnected = status.connected;
            next();
        })
        .catch(() => {
            req.studioConnected = false;
            next();
        });
}

// ─── exports ───────────────────────────────────────────────────────────
module.exports = {
    StudioTcpClient,
    getClient,
    connectionCheckMiddleware,
    CONFIG,
};
