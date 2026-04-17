import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:link2ur/core/design/app_colors.dart';
import 'package:link2ur/core/utils/error_localizer.dart';
import 'package:link2ur/core/utils/l10n_extension.dart';
import 'package:link2ur/core/widgets/location_picker.dart';
import 'package:link2ur/data/models/expert_team.dart';
import 'package:link2ur/core/utils/helpers.dart';
import 'package:link2ur/data/repositories/expert_team_repository.dart';
import 'package:link2ur/features/expert_team/bloc/expert_team_bloc.dart';

class EditTeamProfileView extends StatelessWidget {
  final String expertId;
  const EditTeamProfileView({super.key, required this.expertId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
      )..add(ExpertTeamLoadDetail(expertId)),
      child: _EditBody(expertId: expertId),
    );
  }
}

class _EditBody extends StatefulWidget {
  final String expertId;
  const _EditBody({required this.expertId});

  @override
  State<_EditBody> createState() => _EditBodyState();
}

class _EditBodyState extends State<_EditBody> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _initialized = false;
  String? _location;
  double? _latitude;
  double? _longitude;
  int? _serviceRadiusKm;

  // Avatar state
  Uint8List? _avatarBytes;
  String? _newAvatarUrl;
  bool _uploadingAvatar = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _initFromTeam(ExpertTeam team) {
    if (!_initialized) {
      _nameCtrl.text = team.name;
      _bioCtrl.text = team.bio ?? '';
      _location = team.location;
      _latitude = team.latitude;
      _longitude = team.longitude;
      _serviceRadiusKm = team.serviceRadiusKm;
      _initialized = true;
    }
  }

  Future<void> _pickFromGallery() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    await _cropAndUpload(file);
  }

  Future<void> _pickFromCamera() async {
    final file = await _imagePicker.pickImage(source: ImageSource.camera);
    if (file == null || !mounted) return;
    await _cropAndUpload(file);
  }

  Future<void> _cropAndUpload(XFile file) async {
    final l10n = context.l10n;
    final repo = context.read<ExpertTeamRepository>();
    final messenger = ScaffoldMessenger.of(context);

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: 512,
      maxHeight: 512,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: l10n.profileSelectAvatar,
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.primary,
          cropStyle: CropStyle.circle,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: l10n.profileSelectAvatar,
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (croppedFile == null || !mounted) return;

    final bytes = await croppedFile.readAsBytes();
    final filename = croppedFile.path.split('/').last;

    setState(() {
      _avatarBytes = bytes;
      _uploadingAvatar = true;
    });

    try {
      final url = await repo.uploadAvatar(bytes, filename);
      if (!mounted) return;
      setState(() {
        _newAvatarUrl = url;
        _uploadingAvatar = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _avatarBytes = null;
        _uploadingAvatar = false;
      });
      final errorMsg = context.localizeError(e.toString());
      messenger.showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  void _showImageSourceSheet() {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.profileAvatarFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.profileAvatarFromCamera),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(l10n.commonCancel),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpertTeamBloc, ExpertTeamState>(
      listenWhen: (prev, curr) =>
          curr.actionMessage != prev.actionMessage ||
          curr.errorMessage != prev.errorMessage,
      listener: (context, state) {
        final msg = state.actionMessage ?? state.errorMessage;
        if (msg != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(msg))),
          );
          if (state.actionMessage != null) {
            context.pop();
          }
        }
      },
      builder: (context, state) {
        final team = state.currentTeam;
        if (team != null) _initFromTeam(team);

        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.expertTeamEditProfileTitle)),
          body: team == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        // Avatar
                        Center(
                          child: GestureDetector(
                            onTap: _uploadingAvatar ? null : _showImageSourceSheet,
                            child: Stack(
                              children: [
                                if (_avatarBytes != null)
                                  CircleAvatar(
                                    radius: 48,
                                    backgroundImage: MemoryImage(_avatarBytes!),
                                  )
                                else
                                  CircleAvatar(
                                    radius: 48,
                                    backgroundImage: team.avatar != null
                                        ? NetworkImage(Helpers.getImageUrl(team.avatar!))
                                        : null,
                                    child: team.avatar == null
                                        ? const Icon(Icons.group, size: 40)
                                        : null,
                                  ),
                                if (_uploadingAvatar)
                                  const Positioned.fill(
                                    child: CircleAvatar(
                                      radius: 48,
                                      backgroundColor: Colors.black38,
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: context.l10n.expertTeamTeamName,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? context.l10n.expertTeamEditProfileValidateName
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _bioCtrl,
                          decoration: InputDecoration(
                            labelText: context.l10n.expertTeamBio,
                            border: const OutlineInputBorder(),
                          ),
                          maxLines: 4,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.expertTeamEditProfileReviewNote,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.l10n.baseAddress,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        LocationInputField(
                          initialValue: _location,
                          initialLatitude: _latitude,
                          initialLongitude: _longitude,
                          onChanged: (value) => _location = value,
                          onLocationPicked: (address, lat, lng) {
                            setState(() {
                              _location = address;
                              _latitude = lat;
                              _longitude = lng;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.defaultServiceRadius,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [5, 10, 25, 50, 0].map((r) {
                            final label = r == 0
                                ? context.l10n.serviceRadiusWholeCity
                                : context.l10n.serviceRadiusKm(r);
                            return ChoiceChip(
                              label: Text(label),
                              selected: _serviceRadiusKm == r,
                              onSelected: (selected) {
                                setState(() {
                                  _serviceRadiusKm = selected ? r : null;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: state.status == ExpertTeamStatus.loading || _uploadingAvatar
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) return;
                                    final newName = _nameCtrl.text.trim() != team.name
                                        ? _nameCtrl.text.trim()
                                        : null;
                                    final newBio = _bioCtrl.text.trim() != (team.bio ?? '')
                                        ? _bioCtrl.text.trim()
                                        : null;
                                    final locationChanged = _location != team.location ||
                                        _latitude != team.latitude ||
                                        _longitude != team.longitude ||
                                        _serviceRadiusKm != team.serviceRadiusKm;

                                    if (newName == null && newBio == null && _newAvatarUrl == null && !locationChanged) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.l10n.expertTeamEditProfileNoChanges,
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    // Cache context-dependent refs before awaits
                                    final repo = context.read<ExpertTeamRepository>();
                                    final messenger = ScaffoldMessenger.of(context);
                                    final router = GoRouter.of(context);
                                    final savedMsg = context.l10n.commonSaved;
                                    final failedPrefix = context.l10n.expertTeamEditProfileSubmitFailed;

                                    // Profile update (name/bio/avatar) — direct save, no review
                                    if (newName != null || newBio != null || _newAvatarUrl != null) {
                                      try {
                                        await repo.updateProfile(
                                          widget.expertId,
                                          newName: newName,
                                          newBio: newBio,
                                          newAvatar: _newAvatarUrl,
                                        );
                                      } catch (e) {
                                        final detail = context.mounted
                                            ? context.localizeError(e.toString())
                                            : e.toString();
                                        messenger.showSnackBar(
                                          SnackBar(content: Text('$failedPrefix: $detail')),
                                        );
                                        return;
                                      }
                                    }

                                    // Save location directly (no review needed)
                                    if (locationChanged) {
                                      try {
                                        await repo.updateExpertLocation(
                                          widget.expertId,
                                          location: _location,
                                          latitude: _latitude,
                                          longitude: _longitude,
                                          serviceRadiusKm: _serviceRadiusKm,
                                        );
                                      } catch (e) {
                                        final detail = context.mounted
                                            ? context.localizeError(e.toString())
                                            : e.toString();
                                        messenger.showSnackBar(
                                          SnackBar(content: Text(detail)),
                                        );
                                        return;
                                      }
                                    }

                                    // Single saved toast shown after both paths succeed
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(savedMsg)),
                                    );
                                    router.pop();
                                  },
                            child: state.status == ExpertTeamStatus.loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(context.l10n.expertTeamSubmit),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
