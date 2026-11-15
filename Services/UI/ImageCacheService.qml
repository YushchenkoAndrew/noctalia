pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../Helpers/sha256.js" as Checksum
import qs.Commons

Singleton {
  id: root

  // -------------------------------------------------
  // Public Properties
  // -------------------------------------------------
  property bool imageMagickAvailable: false
  property bool initialized: false

  // Cache directories
  readonly property string baseDir: Settings.cacheDir + "images/"
  readonly property string wpThumbDir: baseDir + "wallpapers/thumbnails/"
  readonly property string wpLargeDir: baseDir + "wallpapers/large/"
  readonly property string notificationsDir: baseDir + "notifications/"
  readonly property string contributorsDir: baseDir + "contributors/"

  // Supported image formats - extended list when ImageMagick is available
  readonly property var basicImageFilters: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.bmp"]
  readonly property var extendedImageFilters: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.bmp", "*.webp", "*.avif", "*.heic", "*.heif", "*.tiff", "*.tif", "*.pnm", "*.pgm", "*.ppm", "*.pbm", "*.svg", "*.svgz", "*.ico", "*.icns", "*.jxl", "*.jp2", "*.j2k", "*.exr", "*.hdr", "*.dds", "*.tga"]
  readonly property var imageFilters: imageMagickAvailable ? extendedImageFilters : basicImageFilters

  // -------------------------------------------------
  // Internal State
  // -------------------------------------------------
  property var pendingRequests: ({})
  property var fallbackQueue: []
  property bool fallbackProcessing: false

  // Process queues to prevent "too many open files" errors
  property var utilityProcessQueue: []
  property int runningUtilityProcesses: 0
  readonly property int maxConcurrentUtilityProcesses: 16

  // Separate queue for heavy ImageMagick processing (lower concurrency)
  property var imageMagickQueue: []
  property int runningImageMagickProcesses: 0
  readonly property int maxConcurrentImageMagickProcesses: 4

  // -------------------------------------------------
  // Signals
  // -------------------------------------------------
  signal cacheHit(string cacheKey, string cachedPath)
  signal cacheMiss(string cacheKey)
  signal processingComplete(string cacheKey, string cachedPath)
  signal processingFailed(string cacheKey, string error)

  // -------------------------------------------------
  // Initialization
  // -------------------------------------------------
  function init() {
    Logger.i("ImageCache", "Service started");
    createDirectories();
    cleanupOldCache();
    checkMagickProcess.running = true;
  }

  function createDirectories() {
    Quickshell.execDetached(["mkdir", "-p", wpThumbDir]);
    Quickshell.execDetached(["mkdir", "-p", wpLargeDir]);
    Quickshell.execDetached(["mkdir", "-p", notificationsDir]);
    Quickshell.execDetached(["mkdir", "-p", contributorsDir]);
  }

  function cleanupOldCache() {
    const dirs = [wpThumbDir, wpLargeDir, notificationsDir, contributorsDir];
    dirs.forEach(function (dir) {
      Quickshell.execDetached(["find", dir, "-type", "f", "-mtime", "+15", "-delete"]);
    });
    Logger.d("ImageCache", "Cleanup triggered for files older than 15 days");
  }

  // -------------------------------------------------
  // Public API: Get Notification Icon (64x64)
  // -------------------------------------------------
  function getNotificationIcon(imageUri, appName, summary, callback) {
    if (!imageUri || imageUri === "") {
      callback("", false);
      return;
    }

    // Resolve bare file path for temp check
    const filePath = imageUri.startsWith("file://") ? imageUri.substring(7) : imageUri;

    // File paths in persistent locations are used directly, not cached
    if ((imageUri.startsWith("/") || imageUri.startsWith("file://")) && !isTemporaryPath(filePath)) {
      callback(imageUri, false);
      return;
    }

    const cacheKey = generateNotificationKey(imageUri, appName, summary);
    const cachedPath = notificationsDir + cacheKey + ".png";

    // Temporary file paths are copied to cache before the source is cleaned up
    if (imageUri.startsWith("/") || imageUri.startsWith("file://")) {
      processRequest(cacheKey, cachedPath, imageUri, callback, function () {
        copyTempFileToCache(filePath, cachedPath, cacheKey);
      });
      return;
    }

    processRequest(cacheKey, cachedPath, imageUri, callback, function () {
      // Notifications always use Qt fallback (image:// URIs can't be read by ImageMagick)
      queueFallbackProcessing(imageUri, cachedPath, cacheKey, 64);
    });
  }

  // Check if a path is in a temporary directory that may be cleaned up
  function isTemporaryPath(path) {
    return path.startsWith("/tmp/");
  }

  // Copy a temporary file to the cache directory
  function copyTempFileToCache(sourcePath, destPath, cacheKey) {
    const srcEsc = sourcePath.replace(/'/g, "'\\''");
    const dstEsc = destPath.replace(/'/g, "'\\''");

    const processString = `
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["cp", "--", "${srcEsc}", "${dstEsc}"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
      }
    `;

    queueUtilityProcess({
                          name: "CopyTempFile_" + cacheKey,
                          processString: processString,
                          onComplete: function (exitCode) {
                            if (exitCode === 0) {
                              Logger.d("ImageCache", "Temp file cached:", destPath);
                              notifyCallbacks(cacheKey, destPath, true);
                            } else {
                              Logger.w("ImageCache", "Failed to cache temp file:", sourcePath);
                              notifyCallbacks(cacheKey, "", false);
                            }
                          },
                          onError: function () {
                            Logger.e("ImageCache", "Error caching temp file:", sourcePath);
                            notifyCallbacks(cacheKey, "", false);
                          }
                        });
  }

  function generateNotificationKey(imageUri, appName, summary) {
    if (imageUri.startsWith("image://qsimage/")) {
      return Checksum.sha256(appName + "|" + summary);
    }
    return Checksum.sha256(imageUri);
  }

  // -------------------------------------------------
  // Request Processing (with coalescing)
  // -------------------------------------------------
  function processRequest(cacheKey, cachedPath, sourcePath, callback, processFn) {
    // Check if already processing this request
    if (pendingRequests[cacheKey]) {
      pendingRequests[cacheKey].callbacks.push(callback);
      Logger.d("ImageCache", "Coalescing request for:", cacheKey);
      return;
    }

    // Check cache first
    checkFileExists(cachedPath, function (exists) {
      if (exists) {
        Logger.d("ImageCache", "Cache hit:", cachedPath);
        callback(cachedPath, true);
        cacheHit(cacheKey, cachedPath);
        return;
      }

      // Re-check pendingRequests (race condition fix)
      if (pendingRequests[cacheKey]) {
        pendingRequests[cacheKey].callbacks.push(callback);
        return;
      }

      // Start new processing
      Logger.d("ImageCache", "Cache miss, processing:", sourcePath);
      cacheMiss(cacheKey);
      pendingRequests[cacheKey] = {
        callbacks: [callback],
        sourcePath: sourcePath
      };

      processFn();
    });
  }

  function notifyCallbacks(cacheKey, path, success) {
    const request = pendingRequests[cacheKey];
    if (request) {
      request.callbacks.forEach(function (cb) {
        cb(path, success);
      });
      delete pendingRequests[cacheKey];
    }

    if (success) {
      processingComplete(cacheKey, path);
    } else {
      processingFailed(cacheKey, "Processing failed");
    }
  }

  // -------------------------------------------------
  // Generic Process Runner (with queue for ImageMagick)
  // -------------------------------------------------

  // Queue an ImageMagick process and run it when a slot is available
  function queueImageMagickProcess(request) {
    imageMagickQueue.push(request);
    processImageMagickQueue();
  }

  // Process queued ImageMagick requests up to the concurrency limit
  function processImageMagickQueue() {
    while (runningImageMagickProcesses < maxConcurrentImageMagickProcesses && imageMagickQueue.length > 0) {
      const request = imageMagickQueue.shift();
      runImageMagickProcess(request);
    }
  }

  // Actually run an ImageMagick process
  function runImageMagickProcess(request) {
    runningImageMagickProcesses++;

    const processString = `
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["sh", "-c", ""]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
      }
    `;

    try {
      const processObj = Qt.createQmlObject(processString, root, "ImageProcess_" + request.cacheKey);
      processObj.command = ["sh", "-c", request.command];

      processObj.exited.connect(function (exitCode) {
        processObj.destroy();
        runningImageMagickProcesses--;
        request.onComplete(exitCode, processObj);
        processImageMagickQueue();
      });

      processObj.running = true;
    } catch (e) {
      Logger.e("ImageCache", "Failed to create process:", e);
      runningImageMagickProcesses--;
      request.onError(e);
      processImageMagickQueue();
    }
  }

  function runProcess(command, cacheKey, outputPath, sourcePath) {
    queueImageMagickProcess({
                              command: command,
                              cacheKey: cacheKey,
                              onComplete: function (exitCode, proc) {
                                if (exitCode !== 0) {
                                  const stderrText = proc.stderr.text || "";
                                  Logger.e("ImageCache", "Processing failed:", stderrText);
                                  notifyCallbacks(cacheKey, sourcePath, false);
                                } else {
                                  Logger.d("ImageCache", "Processing complete:", outputPath);
                                  notifyCallbacks(cacheKey, outputPath, true);
                                }
                              },
                              onError: function () {
                                notifyCallbacks(cacheKey, sourcePath, false);
                              }
                            });
  }

  // -------------------------------------------------
  // Qt Fallback Renderer
  // -------------------------------------------------
  PanelWindow {
    id: fallbackRenderer
    implicitWidth: 0
    implicitHeight: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "noctalia-image-cache-renderer"
    color: "transparent"
    mask: Region {}

    Image {
      id: fallbackImage
      property string cacheKey: ""
      property string destPath: ""
      property int targetSize: 256

      width: targetSize
      height: targetSize
      visible: true
      cache: false
      asynchronous: true
      fillMode: Image.PreserveAspectCrop
      mipmap: true
      antialiasing: true

      onStatusChanged: {
        if (!cacheKey)
        return;

        if (status === Image.Ready) {
          grabToImage(function (result) {
            if (result.saveToFile(destPath)) {
              Logger.d("ImageCache", "Fallback cache created:", destPath);
              root.notifyCallbacks(cacheKey, destPath, true);
            } else {
              Logger.e("ImageCache", "Failed to save fallback cache");
              root.notifyCallbacks(cacheKey, "", false);
            }
            processNextFallback();
          });
        } else if (status === Image.Error) {
          Logger.e("ImageCache", "Fallback image load failed");
          root.notifyCallbacks(cacheKey, "", false);
          processNextFallback();
        }
      }

      function processNextFallback() {
        cacheKey = "";
        destPath = "";
        source = "";

        if (fallbackQueue.length > 0) {
          const next = fallbackQueue.shift();
          cacheKey = next.cacheKey;
          destPath = next.destPath;
          targetSize = next.size;
          source = next.sourcePath;
        } else {
          fallbackProcessing = false;
        }
      }
    }
  }

  function queueFallbackProcessing(sourcePath, destPath, cacheKey, size) {
    fallbackQueue.push({
                         sourcePath: sourcePath,
                         destPath: destPath,
                         cacheKey: cacheKey,
                         size: size
                       });

    if (!fallbackProcessing) {
      fallbackProcessing = true;
      const item = fallbackQueue.shift();
      fallbackImage.cacheKey = item.cacheKey;
      fallbackImage.destPath = item.destPath;
      fallbackImage.targetSize = item.size;
      fallbackImage.source = item.sourcePath;
    }
  }

  // -------------------------------------------------
  // Utility Functions (with process queue to prevent fd exhaustion)
  // -------------------------------------------------

  // Queue a utility process and run it when a slot is available
  function queueUtilityProcess(request) {
    utilityProcessQueue.push(request);
    processUtilityQueue();
  }

  // Process queued utility requests up to the concurrency limit
  function processUtilityQueue() {
    while (runningUtilityProcesses < maxConcurrentUtilityProcesses && utilityProcessQueue.length > 0) {
      const request = utilityProcessQueue.shift();
      runUtilityProcess(request);
    }
  }

  // Actually run a utility process
  function runUtilityProcess(request) {
    runningUtilityProcesses++;

    try {
      const processObj = Qt.createQmlObject(request.processString, root, request.name);

      processObj.exited.connect(function (exitCode) {
        processObj.destroy();
        runningUtilityProcesses--;
        request.onComplete(exitCode, processObj);
        processUtilityQueue();
      });

      processObj.running = true;
    } catch (e) {
      Logger.e("ImageCache", "Failed to create " + request.name + ":", e);
      runningUtilityProcesses--;
      request.onError(e);
      processUtilityQueue();
    }
  }

  function checkFileExists(filePath, callback) {
    const pathEsc = filePath.replace(/'/g, "'\\''");
    const processString = `
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["test", "-f", "${pathEsc}"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
      }
    `;

    queueUtilityProcess({
                          name: "FileExistsProcess",
                          processString: processString,
                          onComplete: function (exitCode) {
                            callback(exitCode === 0);
                          },
                          onError: function () {
                            callback(false);
                          }
                        });
  }

  function invalidateNotification(imageId) {
    const path = notificationsDir + imageId + ".png";
    Quickshell.execDetached(["rm", "-f", path]);
  }

  // -------------------------------------------------
  // Clear Cache Functions
  // -------------------------------------------------
  function clearAll() {
    Logger.i("ImageCache", "Clearing all cache");
    clearThumbnails();
    clearLarge();
    clearNotifications();
    clearContributors();
  }

  function clearThumbnails() {
    Logger.i("ImageCache", "Clearing thumbnails cache");
    Quickshell.execDetached(["rm", "-rf", wpThumbDir]);
    Quickshell.execDetached(["mkdir", "-p", wpThumbDir]);
  }

  function clearLarge() {
    Logger.i("ImageCache", "Clearing large cache");
    Quickshell.execDetached(["rm", "-rf", wpLargeDir]);
    Quickshell.execDetached(["mkdir", "-p", wpLargeDir]);
  }

  function clearNotifications() {
    Logger.i("ImageCache", "Clearing notifications cache");
    Quickshell.execDetached(["rm", "-rf", notificationsDir]);
    Quickshell.execDetached(["mkdir", "-p", notificationsDir]);
  }

  function clearContributors() {
    Logger.i("ImageCache", "Clearing contributors cache");
    Quickshell.execDetached(["rm", "-rf", contributorsDir]);
    Quickshell.execDetached(["mkdir", "-p", contributorsDir]);
  }

  // -------------------------------------------------
  // ImageMagick Detection
  // -------------------------------------------------
  Process {
    id: checkMagickProcess
    command: ["sh", "-c", "command -v magick"]
    running: false

    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      root.imageMagickAvailable = (exitCode === 0);
      root.initialized = true;
      if (root.imageMagickAvailable) {
        Logger.i("ImageCache", "ImageMagick available");
      } else {
        Logger.w("ImageCache", "ImageMagick not found, using Qt fallback");
      }
    }
  }
}
