/**
 * 翻译请求队列管理器
 * 用于限制并发翻译请求数量，防止过多请求导致性能问题
 */

interface QueuedRequest {
  text: string;
  targetLang: string;
  sourceLang?: string;
  resolve: (value: string) => void;
  reject: (error: any) => void;
  timestamp: number;
}

class TranslationQueue {
  private queue: QueuedRequest[] = [];
  private processing: Set<string> = new Set();
  private maxConcurrent: number = 3; // 最大并发数
  private maxQueueSize: number = 50; // 最大队列长度
  private requestTimeout: number = 30000; // 请求超时时间（30秒）

  /**
   * 添加翻译请求到队列
   */
  async enqueue(
    text: string,
    targetLang: string,
    sourceLang: string | undefined,
    translateFn: (text: string, targetLang: string, sourceLang?: string) => Promise<string>
  ): Promise<string> {
    const requestKey = `${text}::${sourceLang || 'auto'}::${targetLang}`;

    // 如果正在处理，等待完成
    if (this.processing.has(requestKey)) {
      return new Promise((resolve, reject) => {
        // 等待当前请求完成
        const checkInterval = setInterval(() => {
          if (!this.processing.has(requestKey)) {
            clearInterval(checkInterval);
            // 重新尝试（可能已缓存）
            this.enqueue(text, targetLang, sourceLang, translateFn)
              .then(resolve)
              .catch(reject);
          }
        }, 100);
        
        // 超时处理
        setTimeout(() => {
          clearInterval(checkInterval);
          reject(new Error('翻译请求超时'));
        }, this.requestTimeout);
      });
    }

    // 如果队列已满，拒绝新请求
    if (this.queue.length >= this.maxQueueSize) {
      throw new Error('翻译队列已满，请稍后重试');
    }

    return new Promise((resolve, reject) => {
      const request: QueuedRequest = {
        text,
        targetLang,
        sourceLang,
        resolve,
        reject,
        timestamp: Date.now()
      };

      this.queue.push(request);
      this.processQueue(translateFn);
    });
  }

  /**
   * 处理队列
   */
  private async processQueue(
    translateFn: (text: string, targetLang: string, sourceLang?: string) => Promise<string>
  ) {
    // 如果已达到最大并发数，等待
    if (this.processing.size >= this.maxConcurrent) {
      return;
    }

    // 如果队列为空，返回
    if (this.queue.length === 0) {
      return;
    }

    // 取出队列中的第一个请求
    const request = this.queue.shift();
    if (!request) {
      return;
    }

    const requestKey = `${request.text}::${request.sourceLang || 'auto'}::${request.targetLang}`;
    this.processing.add(requestKey);

    // 执行翻译
    translateFn(request.text, request.targetLang, request.sourceLang)
      .then((result) => {
        request.resolve(result);
      })
      .catch((error) => {
        request.reject(error);
      })
      .finally(() => {
        this.processing.delete(requestKey);
        // 继续处理队列
        this.processQueue(translateFn);
      });
  }

  /**
   * 获取队列状态
   */
  getStatus() {
    return {
      queueLength: this.queue.length,
      processingCount: this.processing.size,
      maxConcurrent: this.maxConcurrent,
      maxQueueSize: this.maxQueueSize
    };
  }

  /**
   * 清空队列
   */
  clear() {
    // 拒绝所有待处理的请求
    this.queue.forEach(request => {
      request.reject(new Error('翻译队列已清空'));
    });
    this.queue = [];
  }
}

// 单例模式
export const translationQueue = new TranslationQueue();
