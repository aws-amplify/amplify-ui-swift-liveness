# Changelog

## 1.3.2 (2024-08-20)

## 1.3.1 (2024-08-19)

### Bug Fixes

- Returning .userCancelled when the app goes to the background during a Liveness check. (#167)

## 1.3.0 (2024-08-06)

### Features

- Adding new error when the camera is not available even though permissions were granted. (#163)

## 1.2.18 (2024-07-29)

### Bug Fixes

- Fixing a crash when attempting to call finishWriting (#161)

## 1.2.17 (2024-07-11)

### Bug Fixes

- Updating the camera frame position when the subviews are laid out (#158)

## 1.2.16 (2024-07-02)

### Bug Fixes

- Fixing video not being mirrored in the 'Get Ready' screen (#153)

## 1.2.15 (2024-06-26)

## 1.2.14 (2024-05-15)

## 1.2.13 (2024-05-06)

## 1.2.12 (2024-04-25)

### Bug Fixes

- remove strong reference retain cycle from camera preview view model (#135)

## 1.2.11 (2024-04-23)

## 1.2.10 (2024-04-18)

## 1.2.9 (2024-04-11)

### Bug Fixes

- prevent AVCaptureSession from starting during session configuration (#124)

## 1.2.8 (2024-04-09)

### Bug Fixes

- update preview layer to be optional and check for nil values (#122)

## 1.2.7 (2024-03-18)

### Bug Fixes

- use higher priority task queue for AVCaptureSession (#118)

## 1.2.6 (2024-03-11)

## 1.2.5 (2024-02-08)

### Bug Fixes

- add additional guard for finishing AVAssetWriter (#108)

## 1.2.4 (2024-02-05)

### Bug Fixes

- ensure video image is mirrored (#105)

## 1.2.3 (2024-02-05)

### Bug Fixes

- cleanup camera session in the preview page (#101)

## 1.2.2 (2024-01-10)

### Bug Fixes

- resolve race condition when starting AVCaptureSession (#93)

## 1.2.1 (2023-12-05)

### Bug Fixes

- send the final video event at a delayed time interval (#87)

## 1.2.0 (2023-12-04)

### Features

- **ux**: update get ready page with new preview screen (#78)

## 1.1.4 (2023-10-31)

### Bug Fixes

- prevent duplicate session timeout error messages (#70)

## 1.1.3 (2023-10-23)

### Bug Fixes

- update session timed out error handling (#65)

## 1.1.2 (2023-10-05)


