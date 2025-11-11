declare module 'dompurify' {
  interface DOMPurifyI {
    sanitize(source: string | Node, config?: any): string;
    addHook(hook: string, cb: (node: any, data: any, config?: any) => void): void;
    removeHook(entryPoint: string): void;
    removeAllHooks(): void;
    version: string;
    removed: any[];
    isSupported: boolean;
  }

  function createDOMPurify(window?: Window): DOMPurifyI;
  
  const DOMPurify: DOMPurifyI;
  export default DOMPurify;
  export = DOMPurify;
}

