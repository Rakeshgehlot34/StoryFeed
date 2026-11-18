import 'dart:math' as math;

import '../../processing/domain/audio_graph_builder.dart';
import '../../processing/domain/filter_graph_builder.dart';
import 'models/edit_project.dart';

/// Compiled FFmpeg execution arguments for exporting an [EditProject].
class EditorCompiledCommand {
  final List<String> arguments;
  final String? tempOverlayPng;

  const EditorCompiledCommand({required this.arguments, this.tempOverlayPng});
}

/// Pure compiler translating a high-level non-destructive [EditProject]
/// into a 1-pass FFmpeg command line with video/audio filter complexes.
class EditorFilterCompiler {
  EditorFilterCompiler._();

  /// Compiles a production 1-pass export command for [EditProject].
  static EditorCompiledCommand compileExport({
    required EditProject project,
    required String resolvedInputPath,
    required String outputPath,
    String? renderedTextPngPath,
    bool isSoftwareFallback = false,
  }) {
    project.validate();

    final args = <String>['-y'];

    // 1. Seeking & Trimming for Input 0
    if (project.trim.startSeconds > 0) {
      args.addAll(['-ss', project.trim.startSeconds.toStringAsFixed(3)]);
    }
    if (project.activeTrimDuration > 0) {
      args.addAll(['-t', project.activeTrimDuration.toStringAsFixed(3)]);
    }

    // Input 0: Main Video
    args.addAll(['-i', resolvedInputPath]);

    // Track additional input indexes
    int nextInputIdx = 1;
    int? watermarkInputIdx;
    int? textOverlayInputIdx;

    if (project.watermark != null && project.watermark!.imagePath.isNotEmpty) {
      watermarkInputIdx = nextInputIdx++;
      args.addAll(['-i', project.watermark!.imagePath]);
    }

    if (renderedTextPngPath != null && renderedTextPngPath.isNotEmpty) {
      textOverlayInputIdx = nextInputIdx++;
      args.addAll(['-i', renderedTextPngPath]);
    }

    // 2. Build Video Filter Stages
    final (brightness, contrast, saturation) = _resolveColorGrading(
      project.color,
    );

    final baseVf = FilterGraphBuilder.buildVideoFilterChain(
      cropX: project.transform.cropX,
      cropY: project.transform.cropY,
      cropWidth: project.transform.cropWidth,
      cropHeight: project.transform.cropHeight,
      rotationDegrees: project.transform.rotationDegrees,
      hflip: project.transform.hflip,
      vflip: project.transform.vflip,
      speed: project.speed.speed,
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
      fadeInSeconds: project.fade.fadeInSeconds > 0
          ? project.fade.fadeInSeconds
          : null,
      fadeOutSeconds: project.fade.fadeOutSeconds > 0
          ? project.fade.fadeOutSeconds
          : null,
      totalDurationSeconds: project.outputDuration,
      reverse: project.reverse,
    );

    // 3. Canvas Scaling & Aspect Ratio Fit
    final (canvasWidth, canvasHeight) = project.canvas.aspectRatio.dimensions;
    final hasCanvasChange =
        project.canvas.aspectRatio != TargetAspectRatio.original &&
        canvasWidth > 0 &&
        canvasHeight > 0;

    String currentVideoLabel = '[0:v]';
    final complexFilterStages = <String>[];

    // Apply base transformations to input 0
    if (baseVf != null && baseVf.isNotEmpty) {
      complexFilterStages.add('$currentVideoLabel$baseVf[v_base]');
      currentVideoLabel = '[v_base]';
    }

    // Apply Canvas Fit Mode
    if (hasCanvasChange) {
      final cw = canvasWidth;
      final ch = canvasHeight;

      if (project.canvas.fitMode == CanvasFitMode.cropToFill) {
        complexFilterStages.add(
          '$currentVideoLabel scale=$cw:$ch:force_original_aspect_ratio=increase,crop=$cw:$ch,setsar=1[v_canvas]',
        );
        currentVideoLabel = '[v_canvas]';
      } else if (project.canvas.fitMode == CanvasFitMode.fitWithBlur) {
        final blurBg =
            '$currentVideoLabel split=2[v_fg_in][v_bg_in];'
            '[v_bg_in]scale=$cw:$ch:force_original_aspect_ratio=increase,crop=$cw:$ch,'
            'boxblur=luma_radius=min(h\\,w)/20:luma_power=2[bg_blurred];'
            '[v_fg_in]scale=$cw:$ch:force_original_aspect_ratio=decrease[fg_scaled];'
            '[bg_blurred][fg_scaled]overlay=(W-w)/2:(H-h)/2,setsar=1[v_canvas]';
        complexFilterStages.add(blurBg);
        currentVideoLabel = '[v_canvas]';
      } else {
        // Solid color letterbox / pillarbox
        final hexColor = _formatFFmpegHexColor(
          project.canvas.backgroundColorHex,
        );
        complexFilterStages.add(
          '$currentVideoLabel scale=$cw:$ch:force_original_aspect_ratio=decrease,'
          'pad=$cw:$ch:(ow-iw)/2:(oh-ih)/2:color=$hexColor,setsar=1[v_canvas]',
        );
        currentVideoLabel = '[v_canvas]';
      }
    }

    // Watermark Overlay
    if (watermarkInputIdx != null && project.watermark != null) {
      final wm = project.watermark!;
      final wmCoords = wm.position.ffmpegCoordinates;
      final scaleFactor = wm.scale.clamp(0.05, 0.4);
      final opacity = wm.opacity.clamp(0.1, 1.0);

      complexFilterStages.add(
        '[$watermarkInputIdx:v]format=rgba,colorchannelmixer=aa=$opacity,'
        'scale=iw*$scaleFactor:-1[wm_scaled];'
        '$currentVideoLabel[wm_scaled]overlay=$wmCoords:shortest=1[v_wm]',
      );
      currentVideoLabel = '[v_wm]';
    }

    // Text Badge Overlay
    if (textOverlayInputIdx != null && project.textOverlay != null) {
      final textCoords = project.textOverlay!.position.ffmpegCoordinates;
      complexFilterStages.add(
        '$currentVideoLabel[$textOverlayInputIdx:v]overlay=$textCoords:shortest=1[v_text]',
      );
      currentVideoLabel = '[v_text]';
    }

    // 4. Audio Filters
    final audioFilterStages = <String>[];
    if (project.speed.preservePitch && project.speed.isModified) {
      audioFilterStages.addAll(
        AudioGraphBuilder.buildAtempoChain(project.speed.speed),
      );
    }
    if (project.reverse) {
      audioFilterStages.add('areverse');
    }
    if (project.fade.fadeAudio && project.fade.fadeInSeconds > 0) {
      audioFilterStages.add(
        'afade=t=in:st=0:d=${project.fade.fadeInSeconds.toStringAsFixed(3)}',
      );
    }
    if (project.fade.fadeAudio &&
        project.fade.fadeOutSeconds > 0 &&
        project.outputDuration > project.fade.fadeOutSeconds) {
      final st = project.outputDuration - project.fade.fadeOutSeconds;
      audioFilterStages.add(
        'afade=t=out:st=${st.toStringAsFixed(3)}:d=${project.fade.fadeOutSeconds.toStringAsFixed(3)}',
      );
    }

    String? audioMap;
    if (audioFilterStages.isNotEmpty) {
      final afString = audioFilterStages.join(',');
      complexFilterStages.add('[0:a]$afString[outa]');
      audioMap = '[outa]';
    }

    // If complex filter stages were generated, emit -filter_complex
    if (complexFilterStages.isNotEmpty) {
      args.addAll(['-filter_complex', complexFilterStages.join(';')]);
      args.addAll(['-map', currentVideoLabel]);
      if (audioMap != null) {
        args.addAll(['-map', audioMap]);
      } else {
        args.addAll(['-map', '0:a?']);
      }
    } else {
      args.addAll(['-map', '0:v', '-map', '0:a?']);
    }

    // 5. Codec & Output Options
    args.addAll(['-t', project.outputDuration.toStringAsFixed(3)]);

    if (isSoftwareFallback) {
      args.addAll([
        '-c:v',
        'libx264',
        '-profile:v',
        'baseline',
        '-level',
        '3.1',
        '-preset',
        'ultrafast',
        '-crf',
        '24',
        '-c:a',
        'aac',
        '-b:a',
        '128k',
        '-pix_fmt',
        'yuv420p',
        outputPath,
      ]);
    } else {
      args.addAll([
        '-c:v',
        'libx264',
        '-preset',
        'veryfast',
        '-crf',
        '22',
        '-c:a',
        'aac',
        '-b:a',
        '128k',
        '-pix_fmt',
        'yuv420p',
        '-movflags',
        '+faststart',
        outputPath,
      ]);
    }

    return EditorCompiledCommand(
      arguments: args,
      tempOverlayPng: renderedTextPngPath,
    );
  }

  /// Compiles a rapid, low-overhead preview command generating a short clip (e.g. 5 seconds).
  static List<String> compilePreview({
    required EditProject project,
    required String resolvedInputPath,
    required String previewOutputPath,
    double previewDurationSeconds = 5.0,
  }) {
    final effectivePreviewDuration = math.min(
      previewDurationSeconds,
      project.activeTrimDuration,
    );

    final command = compileExport(
      project: project,
      resolvedInputPath: resolvedInputPath,
      outputPath: previewOutputPath,
      isSoftwareFallback:
          true, // Uses ultrafast preset for immediate UI playback
    );

    // Replace both the input -t duration and the output -t duration
    final modified = List<String>.from(command.arguments);
    final inputTIdx = modified.indexOf('-t');
    if (inputTIdx != -1 && inputTIdx + 1 < modified.length) {
      modified[inputTIdx + 1] = effectivePreviewDuration.toStringAsFixed(3);
    }
    final outputTIdx = modified.lastIndexOf('-t');
    if (outputTIdx != -1 &&
        outputTIdx != inputTIdx &&
        outputTIdx + 1 < modified.length) {
      final outDur = effectivePreviewDuration / project.speed.speed;
      modified[outputTIdx + 1] = outDur.toStringAsFixed(3);
    }

    return modified;
  }

  static (double brightness, double contrast, double saturation)
  _resolveColorGrading(ColorFilterSpec spec) {
    if (spec.preset == ColorFilterPreset.bw) {
      return (spec.brightness, spec.contrast, 0.0);
    } else if (spec.preset == ColorFilterPreset.vibrant) {
      return (spec.brightness, 1.15, 1.35);
    } else if (spec.preset == ColorFilterPreset.cinematic) {
      return (-0.05, 1.25, 0.90);
    } else if (spec.preset == ColorFilterPreset.vintage) {
      return (0.05, 1.10, 0.80);
    }
    return (spec.brightness, spec.contrast, spec.saturation);
  }

  static String _formatFFmpegHexColor(int colorValue) {
    final hex = colorValue.toRadixString(16).padLeft(8, '0');
    final rgbHex = hex.length >= 6 ? hex.substring(hex.length - 6) : '000000';
    return '0x$rgbHex';
  }
}
