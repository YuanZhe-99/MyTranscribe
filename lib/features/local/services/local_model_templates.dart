/// Purpose: The local models the app offers out of the box, and the package
/// manifests they download.
/// Inputs: None.
/// Returns: `LocalModelTemplate`s and a lookup by artifact id.
/// Side effects: None.
/// Notes: Every URL is pinned — a Hugging Face commit, or a GitHub release
/// asset — and every file carries the SHA-256 its host published for it,
/// fetched on 2026-09-24: Hugging Face's LFS object id, which is the SHA-256 of
/// the file's bytes, and GitHub's asset digest. The downloader checks each
/// against the bytes it received, so a host that replaced a file fails loudly
/// instead of installing something else. Sizes and hashes are never copied
/// from the plan's tables. See `doc/en-us/features/local-models.md`.
library;

import '../../providers/models/model_config.dart';
import '../models/artifact_manifest.dart';
import '../models/engine_capability.dart';
import '../models/local_model_config.dart';

/// The template version the built-in local models are at.
///
/// Raise it when a template changes, so the refresh reaches every device that
/// never overrode the changed field.
///
/// 2: Parakeet moved from a sherpa-onnx package to whisper.cpp's own Parakeet
/// runtime (decision D22 of the local-models plan).
/// 3: Parakeet gained a Core ML package for the Neural Engine (L4).
const localTemplateVersion = 3;

/// The adapter id of whisper.cpp.
const whisperCppAdapterId = 'whisper_cpp';

/// The adapter id of whisper.cpp's Parakeet runtime.
const parakeetCppAdapterId = 'parakeet_cpp';

/// The adapter id of the FluidAudio bridge: Parakeet on the Neural Engine.
const fluidAudioAdapterId = 'fluidaudio';

/// The adapter id of sherpa-onnx.
const sherpaOnnxAdapterId = 'sherpa_onnx';

/// The app's own ceiling on a local window, in seconds.
///
/// Not a promise from any model: Whisper has no limit of its own, Parakeet is
/// bound by attention memory at roughly 24 minutes on a workstation, and one
/// of Qwen's ports fails past two. Ten minutes keeps a phone's memory in hand
/// and progress visible; a memory budget a route reports can lower it.
const localWindowCeilingSeconds = 600;

/// The Hugging Face commit the whisper.cpp model files are pinned to.
const _whisperRevision = '5359861c739e955e79d9a303bcbc70fb988958b1';

/// Where those files come from.
const _whisperBase =
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/$_whisperRevision';

/// The Hugging Face commit of whisper.cpp's Parakeet conversions.
const _parakeetRevision = '35156454d1a39de06863303dd209fd2bed6ee079';

/// The Hugging Face commit of FluidAudio's Parakeet v3 Core ML conversion.
const _parakeetCoreMlRevision = '7dd20fe6b1797d35f5e3307e8b1732d9a178edfe';

/// Where those files come from.
const _parakeetCoreMlBase =
    'https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml/resolve/'
    '$_parakeetCoreMlRevision';

/// The files FluidAudio loads for Parakeet v3 at int8: four compiled Core ML
/// models and the vocabulary, hashed file by file (decision D17).
const _parakeetCoreMlFiles = [
  ArtifactFile(
    path: 'Decoder.mlmodelc/analytics/coremldata.bin',
    bytes: 243,
    sha256: '4238c4e81ecd0dc94bd7dfbb60f7e2cc824107c1ffe0387b8607b72833dba350',
    sourceUrl: '$_parakeetCoreMlBase/Decoder.mlmodelc/analytics/coremldata.bin',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'Decoder.mlmodelc/coremldata.bin',
    bytes: 554,
    sha256: '18647af085d87bd8f3121c8a9b4d4564c1ede038dab63d295b4e745cf2d7fb99',
    sourceUrl: '$_parakeetCoreMlBase/Decoder.mlmodelc/coremldata.bin',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'Decoder.mlmodelc/metadata.json',
    bytes: 3427,
    sha256: 'a39e93cd8371b8ded92635c7804fcd0590f0d1dd9415c6d19a0484be073077d9',
    sourceUrl: '$_parakeetCoreMlBase/Decoder.mlmodelc/metadata.json',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'Decoder.mlmodelc/model.mil',
    bytes: 13110,
    sha256: 'ef2a0a281695398a62fde86ac269c68f73d5b578d7ed3b31f2ba91a2d1ea1f35',
    sourceUrl: '$_parakeetCoreMlBase/Decoder.mlmodelc/model.mil',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'Decoder.mlmodelc/weights/weight.bin',
    bytes: 23604992,
    sha256: '48adf0f0d47c406c8253d4f7fef967436a39da14f5a65e66d5a4b407be355d41',
    sourceUrl: '$_parakeetCoreMlBase/Decoder.mlmodelc/weights/weight.bin',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'Encoder.mlmodelc/analytics/coremldata.bin',
    bytes: 243,
    sha256: '42e638870d73f26b332918a3496ce36793fbb413a81cbd3d16ba01328637a105',
    sourceUrl: '$_parakeetCoreMlBase/Encoder.mlmodelc/analytics/coremldata.bin',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'Encoder.mlmodelc/coremldata.bin',
    bytes: 485,
    sha256: 'd48034a167a82e88fc3df64f60af963ab3983538271175b8319e7d5720a0fb86',
    sourceUrl: '$_parakeetCoreMlBase/Encoder.mlmodelc/coremldata.bin',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'Encoder.mlmodelc/metadata.json',
    bytes: 2921,
    sha256: 'da24da9cca943fb29d7fa8e376d57fca7cb3aa08ca51b956b0b0e56813f087e9',
    sourceUrl: '$_parakeetCoreMlBase/Encoder.mlmodelc/metadata.json',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'Encoder.mlmodelc/model.mil',
    bytes: 959769,
    sha256: 'ed7b19156ca29fa7dfd6891deb9fda4b0e8893f68597c985d135736546a43808',
    sourceUrl: '$_parakeetCoreMlBase/Encoder.mlmodelc/model.mil',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'Encoder.mlmodelc/weights/weight.bin',
    bytes: 445187200,
    sha256: 'e2020f323703477a5b21d7c2d282c403e371afb5962e79877e3033e73ba6f421',
    sourceUrl: '$_parakeetCoreMlBase/Encoder.mlmodelc/weights/weight.bin',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'JointDecisionv3.mlmodelc/analytics/coremldata.bin',
    bytes: 243,
    sha256: '26def4bf73dd56d29dee21c8ef97cb8969e62f6120ed1adc91e46828e2737b6c',
    sourceUrl:
        '$_parakeetCoreMlBase/JointDecisionv3.mlmodelc/analytics/coremldata.bin',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'JointDecisionv3.mlmodelc/coremldata.bin',
    bytes: 521,
    sha256: 'f5fc08b741400f0088492c9e839418b1e18522f19cba28d361dd030c5f398342',
    sourceUrl: '$_parakeetCoreMlBase/JointDecisionv3.mlmodelc/coremldata.bin',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'JointDecisionv3.mlmodelc/metadata.json',
    bytes: 3453,
    sha256: 'd9307211b9a37e0f0ac260c7660b1571a3de25841035cfdf9b58fd40425f890f',
    sourceUrl: '$_parakeetCoreMlBase/JointDecisionv3.mlmodelc/metadata.json',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'JointDecisionv3.mlmodelc/model.mil',
    bytes: 11775,
    sha256: 'be60732943389a047175111a83f8839f3eb39d4803adafa828a0871b2f39818d',
    sourceUrl: '$_parakeetCoreMlBase/JointDecisionv3.mlmodelc/model.mil',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'JointDecisionv3.mlmodelc/weights/weight.bin',
    bytes: 12642764,
    sha256: '4e0e63d840032f7f07ddb1d64446051166281e5491bf22da8a945c41f6eedb3e',
    sourceUrl:
        '$_parakeetCoreMlBase/JointDecisionv3.mlmodelc/weights/weight.bin',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'Preprocessor.mlmodelc/analytics/coremldata.bin',
    bytes: 243,
    sha256: 'c9beeb989c8d66f8be11df59bc6df277ec76cee404f6865b46243835ef562f6d',
    sourceUrl:
        '$_parakeetCoreMlBase/Preprocessor.mlmodelc/analytics/coremldata.bin',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'Preprocessor.mlmodelc/coremldata.bin',
    bytes: 486,
    sha256: 'dbde3f2300842c1fd51ef3ff948a0bcffe65ffd2dca10707f2509f32c1d65b1d',
    sourceUrl: '$_parakeetCoreMlBase/Preprocessor.mlmodelc/coremldata.bin',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'Preprocessor.mlmodelc/metadata.json',
    bytes: 2841,
    sha256: '2a98699e22d279dd37fa1d238aeb1c6db1df0d6fad687775324157689d8f3acf',
    sourceUrl: '$_parakeetCoreMlBase/Preprocessor.mlmodelc/metadata.json',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'Preprocessor.mlmodelc/model.mil',
    bytes: 28181,
    sha256: '4b8518a956450fec57f06c2a21bdffc26973f7f1fa6842fb38fe917f896b6b93',
    sourceUrl: '$_parakeetCoreMlBase/Preprocessor.mlmodelc/model.mil',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'Preprocessor.mlmodelc/weights/weight.bin',
    bytes: 491072,
    sha256: '129b76e3aeafa8afa3ea76d995b964b145fe83700d579f6ff42c4c38fa0968ea',
    sourceUrl: '$_parakeetCoreMlBase/Preprocessor.mlmodelc/weights/weight.bin',
    platforms: _apple,
  ),
  ArtifactFile(
    path: 'parakeet_vocab.json',
    bytes: 151122,
    sha256: '7ec60e05f1b24480736ec0eed40900f4626bce1fa9a60fd700ec7e2a59198735',
    sourceUrl: '$_parakeetCoreMlBase/parakeet_vocab.json',
    platforms: _apple,
  ),
];

/// The sherpa-onnx release holding its speech models.
const _sherpaBase =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models';

/// Where the Whisper licence is published.
const _mitUrl = 'https://github.com/openai/whisper/blob/main/LICENSE';

/// The platforms that can load a Core ML encoder.
const _apple = ['ios', 'macos'];

/// Parakeet TDT 0.6B v3's languages, from NVIDIA's model card.
///
/// Twenty-five European languages; no Chinese, Japanese or Korean, which is
/// the rule the router enforces with this list.
const _parakeetLanguages = [
  'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'hr', 'hu', //
  'it', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'ru', 'sk', 'sl', 'sv', //
  'uk',
];

/// One built-in local model and the packages it may use.
class LocalModelTemplate {
  /// The record to seed.
  final LocalModelConfig model;

  /// Its packages.
  final List<ArtifactManifest> artifacts;

  /// Purpose: Create a template.
  /// Inputs: [model], [artifacts].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const LocalModelTemplate({required this.model, required this.artifacts});
}

/// Purpose: Build the whisper.cpp manifest for one model file.
/// Inputs: The [artifactId], [modelId], [quantization], the model [file]'s
/// name, [bytes] and [sha256], optional Core ML [encoder] and RAM figure.
/// Returns: An [ArtifactManifest].
/// Side effects: None.
/// Notes: Internal helper used within this file only.
ArtifactManifest _whisper({
  required String artifactId,
  required String modelId,
  required String quantization,
  required String file,
  required int bytes,
  required String sha256,
  ({String file, int bytes, String sha256})? encoder,
  int? minimumRamBytes,
}) => ArtifactManifest(
  artifactId: artifactId,
  modelId: modelId,
  adapterId: whisperCppAdapterId,
  format: ArtifactFormat.ggml,
  quantization: quantization,
  revision: _whisperRevision,
  files: [
    ArtifactFile(
      path: file,
      bytes: bytes,
      sha256: sha256,
      sourceUrl: '$_whisperBase/$file',
    ),
    if (encoder != null)
      ArtifactFile(
        path: encoder.file,
        bytes: encoder.bytes,
        sha256: encoder.sha256,
        sourceUrl: '$_whisperBase/${encoder.file}',
        platforms: _apple,
        unpack: ArchiveKind.zip,
      ),
  ],
  licenseId: 'MIT',
  licenseUrl: _mitUrl,
  attribution: 'OpenAI Whisper, converted to GGML by the whisper.cpp project.',
  minimumRamBytes: minimumRamBytes,
  ramEstimateSource: minimumRamBytes == null
      ? EstimateSource.unknown
      : EstimateSource.documented,
);

/// Purpose: Build the Whisper record every Whisper template shares.
/// Inputs: The record [id], its [name] and its package [artifactId].
/// Returns: A [LocalModelConfig].
/// Side effects: None.
/// Notes: Internal helper used within this file only. Whisper detects about a
/// hundred languages, so the record states no restriction.
LocalModelConfig _whisperRecord(String id, String name, String artifactId) =>
    LocalModelConfig(
      id: id,
      templateId: id,
      displayName: name,
      family: LocalModelFamily.whisper,
      maxDurationSeconds: localWindowCeilingSeconds,
      wordTimestamps: Capability.supported,
      segmentTimestamps: Capability.supported,
      supportsPrompt: true,
      artifacts: {
        whisperCppAdapterId: [artifactId],
      },
      templateVersion: localTemplateVersion,
    );

/// Purpose: List the built-in local models.
/// Inputs: None.
/// Returns: The templates, in the order the library shows them.
/// Side effects: None.
/// Notes: Turbo first: it is a quarter the size of large-v3 at a small cost in
/// accuracy, which is the right first download on most devices.
List<LocalModelTemplate> buildLocalModelTemplates() => [
  LocalModelTemplate(
    model: _whisperRecord(
      'local:whisper-large-v3-turbo',
      'Whisper large-v3 turbo',
      'whisper-large-v3-turbo-ggml',
    ),
    artifacts: [
      _whisper(
        artifactId: 'whisper-large-v3-turbo-ggml',
        modelId: 'local:whisper-large-v3-turbo',
        quantization: 'f16',
        file: 'ggml-large-v3-turbo.bin',
        bytes: 1624555275,
        sha256:
            '1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69',
        encoder: (
          file: 'ggml-large-v3-turbo-encoder.mlmodelc.zip',
          bytes: 1173393014,
          sha256:
              '84bedfe895bd7b5de6e8e89a0803dfc5addf8c0c5bc4c937451716bf7cf7988a',
        ),
      ),
    ],
  ),
  LocalModelTemplate(
    model: _whisperRecord(
      'local:whisper-large-v3-turbo-q5',
      'Whisper large-v3 turbo (q5_0)',
      'whisper-large-v3-turbo-q5_0-ggml',
    ),
    artifacts: [
      _whisper(
        artifactId: 'whisper-large-v3-turbo-q5_0-ggml',
        modelId: 'local:whisper-large-v3-turbo-q5',
        quantization: 'q5_0',
        file: 'ggml-large-v3-turbo-q5_0.bin',
        bytes: 574041195,
        sha256:
            '394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2',
      ),
    ],
  ),
  LocalModelTemplate(
    model: _whisperRecord(
      'local:whisper-large-v3',
      'Whisper large-v3',
      'whisper-large-v3-ggml',
    ),
    artifacts: [
      _whisper(
        artifactId: 'whisper-large-v3-ggml',
        modelId: 'local:whisper-large-v3',
        quantization: 'f16',
        file: 'ggml-large-v3.bin',
        bytes: 3095033483,
        sha256:
            '64d182b440b98d5203c4f9bd541544d84c605196c4f7b845dfa11fb23594d1e2',
        encoder: (
          file: 'ggml-large-v3-encoder.mlmodelc.zip',
          bytes: 1175711232,
          sha256:
              '47837be7594a29429ec08620043390c4d6d467f8bd362df09e9390ace76a55a4',
        ),
        // whisper.cpp's README lists about 3.9 GB for the f16 large model.
        minimumRamBytes: 3900000000,
      ),
    ],
  ),
  LocalModelTemplate(
    model: _whisperRecord(
      'local:whisper-large-v3-q5',
      'Whisper large-v3 (q5_0)',
      'whisper-large-v3-q5_0-ggml',
    ),
    artifacts: [
      _whisper(
        artifactId: 'whisper-large-v3-q5_0-ggml',
        modelId: 'local:whisper-large-v3-q5',
        quantization: 'q5_0',
        file: 'ggml-large-v3-q5_0.bin',
        bytes: 1081140203,
        sha256:
            'd75795ecff3f83b5faa89d1900604ad8c780abd5739fae406de19f23ecd98ad1',
      ),
    ],
  ),
  const LocalModelTemplate(
    model: LocalModelConfig(
      id: 'local:parakeet-tdt-0.6b-v3',
      templateId: 'local:parakeet-tdt-0.6b-v3',
      displayName: 'Parakeet TDT 0.6B v3',
      family: LocalModelFamily.parakeet,
      languages: _parakeetLanguages,
      maxDurationSeconds: localWindowCeilingSeconds,
      wordTimestamps: Capability.supported,
      segmentTimestamps: Capability.supported,
      artifacts: {
        parakeetCppAdapterId: ['parakeet-tdt-0.6b-v3-q8_0-ggml'],
        fluidAudioAdapterId: ['parakeet-tdt-0.6b-v3-coreml'],
      },
      templateVersion: localTemplateVersion,
    ),
    artifacts: [
      ArtifactManifest(
        artifactId: 'parakeet-tdt-0.6b-v3-q8_0-ggml',
        modelId: 'local:parakeet-tdt-0.6b-v3',
        adapterId: parakeetCppAdapterId,
        format: ArtifactFormat.ggml,
        quantization: 'q8_0',
        revision: _parakeetRevision,
        files: [
          ArtifactFile(
            path: 'ggml-parakeet-tdt-0.6b-v3-q8_0.bin',
            bytes: 668757119,
            sha256:
                '4d64e9e96c2792186d072fde0034df0ad670cf680a2f53069052ead827fd600e',
            sourceUrl:
                'https://huggingface.co/ggml-org/parakeet-GGUF/resolve/'
                '$_parakeetRevision/ggml-parakeet-tdt-0.6b-v3-q8_0.bin',
          ),
        ],
        licenseId: 'CC-BY-4.0',
        licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
        attribution:
            'NVIDIA parakeet-tdt-0.6b-v3, licensed CC-BY-4.0; converted to '
            'GGML by the whisper.cpp project.',
      ),
      ArtifactManifest(
        artifactId: 'parakeet-tdt-0.6b-v3-coreml',
        modelId: 'local:parakeet-tdt-0.6b-v3',
        adapterId: fluidAudioAdapterId,
        format: ArtifactFormat.coreml,
        quantization: 'int8',
        revision: _parakeetCoreMlRevision,
        files: _parakeetCoreMlFiles,
        licenseId: 'CC-BY-4.0',
        licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
        attribution:
            'NVIDIA parakeet-tdt-0.6b-v3, licensed CC-BY-4.0; converted to '
            'Core ML by FluidInference.',
      ),
    ],
  ),
  const LocalModelTemplate(
    model: LocalModelConfig(
      id: 'local:qwen3-asr-0.6b',
      templateId: 'local:qwen3-asr-0.6b',
      displayName: 'Qwen3-ASR 0.6B',
      family: LocalModelFamily.qwen,
      maxDurationSeconds: localWindowCeilingSeconds,
      wordTimestamps: Capability.unsupported,
      segmentTimestamps: Capability.unsupported,
      supportsKeywords: true,
      artifacts: {
        sherpaOnnxAdapterId: ['qwen3-asr-0.6b-int8-onnx'],
      },
      templateVersion: localTemplateVersion,
    ),
    artifacts: [
      ArtifactManifest(
        artifactId: 'qwen3-asr-0.6b-int8-onnx',
        modelId: 'local:qwen3-asr-0.6b',
        adapterId: sherpaOnnxAdapterId,
        format: ArtifactFormat.onnx,
        quantization: 'int8',
        revision: 'sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25',
        files: [
          ArtifactFile(
            path: 'sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25.tar.bz2',
            bytes: 878702423,
            sha256:
                '393f8a14e2f5fb96746aaab342997a40641001fbd5bf9592a080a8329178ee96',
            sourceUrl:
                '$_sherpaBase/sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25.tar.bz2',
            unpack: ArchiveKind.tarBz2,
          ),
        ],
        licenseId: 'Apache-2.0',
        licenseUrl: 'https://www.apache.org/licenses/LICENSE-2.0',
        attribution:
            'Qwen3-ASR-0.6B by the Qwen team, Alibaba Cloud; converted to '
            'ONNX by the sherpa-onnx project.',
      ),
    ],
  ),
];

/// Purpose: Find a built-in package manifest by id.
/// Inputs: [artifactId].
/// Returns: The manifest, or null when no template has it.
/// Side effects: None.
/// Notes: A package the user added from a file has no template manifest; its
/// manifest exists only in its installed folder.
ArtifactManifest? templateArtifact(String artifactId) {
  for (final template in buildLocalModelTemplates()) {
    for (final artifact in template.artifacts) {
      if (artifact.artifactId == artifactId) return artifact;
    }
  }
  return null;
}
