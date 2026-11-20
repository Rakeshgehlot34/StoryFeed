import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/output/presentation/controllers/output_controller.dart';
import 'package:shorts_splitter/features/plan_review/presentation/screens/plan_review_screen.dart';
import 'package:shorts_splitter/features/video_picker/domain/models/picked_video.dart';
import 'package:shorts_splitter/features/video_picker/presentation/controllers/video_picker_controller.dart';

class _FakeVideoPickerController extends VideoPickerController {
  final PickedVideo _video;
  _FakeVideoPickerController(this._video);

  @override
  Future<PickedVideo?> build() async => _video;
}

class _FakeOutputDirectoryNotifier extends OutputDirectoryNotifier {
  final String _dir;
  _FakeOutputDirectoryNotifier(this._dir);

  @override
  Future<String> build() async => _dir;
}

void main() {
  const testVideo = PickedVideo(
    path: '/test/video.mp4',
    fileName: 'nature_video.mp4',
    baseName: 'nature_video',
    sizeInBytes: 1024 * 1024 * 20,
    duration: Duration(seconds: 120),
    width: 1920,
    height: 1080,
  );

  testWidgets(
    'PlanReviewScreen displays Save Folder Access Required popup when output directory is empty',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoPickerControllerProvider.overrideWith(
              () => _FakeVideoPickerController(testVideo),
            ),
            outputDirectoryProvider.overrideWith(
              // Empty directory to trigger folder permission validation
              () => _FakeOutputDirectoryNotifier(''),
            ),
          ],
          child: const MaterialApp(home: PlanReviewScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Create Shorts button
      final createBtn = find.textContaining('Create 2 Shorts');
      expect(createBtn, findsOneWidget);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // Verify that the permission popup dialog opens immediately!
      expect(find.text('Save Folder Access Required'), findsOneWidget);
      expect(find.text('Choose Save Folder'), findsOneWidget);

      // Cancel the dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify that error message is displayed on screen explaining why it cannot proceed
      expect(
        find.textContaining('A valid save folder is required'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'PlanReviewScreen displays No Clips Selected popup when all clips are deselected and output dir is valid',
    (WidgetTester tester) async {
      final tempDir = Directory.systemTemp.createTempSync('output_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoPickerControllerProvider.overrideWith(
              () => _FakeVideoPickerController(testVideo),
            ),
            outputDirectoryProvider.overrideWith(
              () => _FakeOutputDirectoryNotifier(tempDir.path),
            ),
          ],
          child: const MaterialApp(home: PlanReviewScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Deselect all clips
      final deselectBtn = find.text('Deselect');
      await tester.ensureVisible(deselectBtn);
      await tester.tap(deselectBtn);
      await tester.pumpAndSettle();

      // Tap bottom button (now saying "Select parts to process")
      final processBtn = find.text('Select parts to process');
      expect(processBtn, findsOneWidget);
      await tester.tap(processBtn);
      await tester.pumpAndSettle();

      // Verify popup dialog appears
      expect(find.text('No Clips Selected'), findsOneWidget);
      expect(find.text('Select All Clips'), findsOneWidget);
    },
  );
}
