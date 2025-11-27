import imageCompression from 'browser-image-compression';

export interface CompressionOptions {
  maxSizeMB?: number; // 最大文件大小（MB）
  maxWidthOrHeight?: number; // 最大宽度或高度（像素）
  useWebWorker?: boolean; // 是否使用 Web Worker
  fileType?: string; // 输出文件类型
  initialQuality?: number; // 初始质量（0-1）
}

/**
 * 压缩图片文件
 * @param file 原始图片文件
 * @param options 压缩选项
 * @returns 压缩后的文件
 */
export async function compressImage(
  file: File,
  options: CompressionOptions = {}
): Promise<File> {
  // 默认选项
  const defaultOptions: CompressionOptions = {
    maxSizeMB: 1, // 最大1MB
    maxWidthOrHeight: 1920, // 最大宽度或高度1920px
    useWebWorker: true,
    fileType: file.type, // 保持原始文件类型
    initialQuality: 0.8, // 初始质量80%
  };

  const compressionOptions = { ...defaultOptions, ...options };

  try {
    // 如果文件已经很小，直接返回
    if (file.size <= (compressionOptions.maxSizeMB || 1) * 1024 * 1024) {
      // 检查是否需要调整尺寸
      const img = new Image();
      const objectUrl = URL.createObjectURL(file);
      
      return new Promise((resolve, reject) => {
        img.onload = async () => {
          URL.revokeObjectURL(objectUrl);
          
          // 如果图片尺寸已经符合要求，直接返回
          if (
            img.width <= (compressionOptions.maxWidthOrHeight || 1920) &&
            img.height <= (compressionOptions.maxWidthOrHeight || 1920)
          ) {
            resolve(file);
            return;
          }
          
          // 需要压缩尺寸
          try {
            const compressedFile = await imageCompression(file, compressionOptions);
            resolve(compressedFile);
          } catch (error) {
            reject(error);
          }
        };
        
        img.onerror = () => {
          URL.revokeObjectURL(objectUrl);
          // 如果无法读取图片，返回原文件
          resolve(file);
        };
        
        img.src = objectUrl;
      });
    }

    // 压缩图片
    const compressedFile = await imageCompression(file, compressionOptions);
    return compressedFile;
  } catch (error) {
    console.error('图片压缩失败:', error);
    // 如果压缩失败，返回原文件
    return file;
  }
}

/**
 * 批量压缩图片
 * @param files 图片文件数组
 * @param options 压缩选项
 * @returns 压缩后的文件数组
 */
export async function compressImages(
  files: File[],
  options: CompressionOptions = {}
): Promise<File[]> {
  const compressedFiles: File[] = [];
  
  for (const file of files) {
    try {
      const compressedFile = await compressImage(file, options);
      compressedFiles.push(compressedFile);
    } catch (error) {
      console.error(`压缩图片失败: ${file.name}`, error);
      // 如果压缩失败，使用原文件
      compressedFiles.push(file);
    }
  }
  
  return compressedFiles;
}




