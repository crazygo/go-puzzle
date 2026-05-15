import Flutter
import Foundation

#if canImport(onnxruntime_objc)
import onnxruntime_objc
#endif

final class TerritoryOnnxChannel: NSObject {
  private static let channelName = "go_puzzle/territory_onnx"

#if canImport(onnxruntime_objc)
  private var env: ORTEnv?
  private var session: ORTSession?
  private var loadedModelPath: String?
#endif

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )
    let instance = TerritoryOnnxChannel()
    channel.setMethodCallHandler(instance.handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickMove":
      handlePickMove(call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handlePickMove(_ arguments: Any?, result: @escaping FlutterResult) {
#if canImport(onnxruntime_objc)
    guard let args = arguments as? [String: Any] else {
      result(["usedNative": false, "backend": "ios_onnx", "error": "invalid_arguments"])
      return
    }

    guard let boardSize = args["boardSize"] as? Int, boardSize == 9 else {
      result([
        "usedNative": false,
        "backend": "ios_onnx",
        "error": "only_small_9x9_model_is_supported"
      ])
      return
    }

    guard let modelPath = locateModelPath() else {
      result([
        "usedNative": false,
        "backend": "ios_onnx",
        "error": "katago_territory_9x9.onnx not found in flutter assets"
      ])
      return
    }

    do {
      let session = try ensureSession(modelPath: modelPath)
      let encoded = try encodeInputs(args: args)
      let inputNames = try session.inputNames()
      let outputNames = try session.outputNames()
      guard inputNames.count >= 2, let policyOutputName = outputNames.first else {
        result([
          "usedNative": false,
          "backend": "ios_onnx",
          "error": "unexpected_model_io_layout"
        ])
        return
      }

      let spatialName = inputNames.first { $0.lowercased().contains("spatial") } ?? inputNames[0]
      let globalName = inputNames.first { $0.lowercased().contains("global") } ?? inputNames[min(1, inputNames.count - 1)]
      let outputs = try session.run(
        withInputs: [
          spatialName: encoded.spatial,
          globalName: encoded.global,
        ],
        outputNames: Set([policyOutputName]),
        runOptions: nil
      )

      guard let policyValue = outputs[policyOutputName] else {
        result([
          "usedNative": false,
          "backend": "ios_onnx",
          "error": "policy_output_missing"
        ])
        return
      }

      let policy = try readFloatTensor(policyValue)
      let legalMoves = (args["legalMoves"] as? [Int]) ?? []
      let move = chooseMove(policy: policy, legalMoves: legalMoves, boardSize: boardSize)
      result([
        "usedNative": move != nil,
        "backend": "ios_onnx",
        "move": move ?? [-1, -1]
      ])
    } catch {
      result([
        "usedNative": false,
        "backend": "ios_onnx",
        "error": error.localizedDescription
      ])
    }
#else
    result(["usedNative": false, "backend": "ios_onnx", "error": "onnxruntime_objc_unavailable"])
#endif
  }
}

#if canImport(onnxruntime_objc)
private extension TerritoryOnnxChannel {
  struct EncodedInputs {
    let spatial: ORTValue
    let global: ORTValue
  }

  func ensureSession(modelPath: String) throws -> ORTSession {
    if let session, loadedModelPath == modelPath {
      return session
    }
    if env == nil {
      env = try ORTEnv(loggingLevel: ORTLoggingLevel.warning)
    }
    let options = try ORTSessionOptions()
    if ORTIsCoreMLExecutionProviderAvailable() {
      try? options.appendCoreMLExecutionProvider()
    }
    let created = try ORTSession(
      env: env!,
      modelPath: modelPath,
      sessionOptions: options
    )
    self.session = created
    loadedModelPath = modelPath
    return created
  }

  func locateModelPath() -> String? {
    guard let flutterAssets = Bundle.main.path(
      forResource: "flutter_assets",
      ofType: nil,
      inDirectory: "Frameworks/App.framework"
    ) else {
      return nil
    }
    let modelPath = (flutterAssets as NSString).appendingPathComponent(
      "assets/models/katago_territory_9x9.onnx"
    )
    return FileManager.default.fileExists(atPath: modelPath) ? modelPath : nil
  }

  func encodeInputs(args: [String: Any]) throws -> EncodedInputs {
    guard
      let boardSize = args["boardSize"] as? Int,
      let currentPlayer = args["currentPlayer"] as? Int,
      let cells = args["cells"] as? [Int]
    else {
      throw NSError(domain: "TerritoryOnnxChannel", code: 1)
    }

    let black = 1
    let white = 2
    let empty = 0
    let opponent = currentPlayer == black ? white : black
    let planeCount = 22
    let pointCount = boardSize * boardSize
    var spatial = [Float](repeating: 0, count: planeCount * pointCount)

    func setPlane(_ plane: Int, _ index: Int, _ value: Float) {
      spatial[plane * pointCount + index] = value
    }

    let liberties = computeLiberties(cells: cells, boardSize: boardSize)
    for index in 0..<pointCount {
      let color = cells[index]
      if color == currentPlayer {
        setPlane(0, index, 1)
      } else if color == opponent {
        setPlane(1, index, 1)
      } else if color == empty {
        setPlane(2, index, 1)
      }

      let libertyCount = liberties[index]
      if color == currentPlayer {
        if libertyCount <= 1 {
          setPlane(3, index, 1)
        } else if libertyCount == 2 {
          setPlane(4, index, 1)
        } else {
          setPlane(5, index, 1)
        }
      } else if color == opponent {
        if libertyCount <= 1 {
          setPlane(6, index, 1)
        } else if libertyCount == 2 {
          setPlane(7, index, 1)
        } else {
          setPlane(8, index, 1)
        }
      }

      let row = index / boardSize
      let col = index % boardSize
      let center = boardSize / 2
      let centerBias = max(0, boardSize - abs(row - center) - abs(col - center))
      setPlane(9, index, Float(centerBias) / Float(boardSize))
      setPlane(10, index, Float(adjacentOpponentCount(cells: cells, boardSize: boardSize, index: index, opponent: opponent)) / 4.0)
      setPlane(11, index, Float(adjacentOpponentCount(cells: cells, boardSize: boardSize, index: index, opponent: currentPlayer)) / 4.0)
      setPlane(12, index, row == 0 || col == 0 || row == boardSize - 1 || col == boardSize - 1 ? 1 : 0)
      setPlane(13, index, currentPlayer == black ? 1 : 0)
      setPlane(14, index, currentPlayer == white ? 1 : 0)
    }

    let capturedByBlack = Float((args["capturedByBlack"] as? Int) ?? 0)
    let capturedByWhite = Float((args["capturedByWhite"] as? Int) ?? 0)
    let passCount = Float((args["consecutivePasses"] as? Int) ?? 0)
    let difficultyName = (args["difficulty"] as? String) ?? "intermediate"
    let difficultyIndex: Float
    if difficultyName == "beginner" {
      difficultyIndex = 0
    } else if difficultyName == "advanced" {
      difficultyIndex = 2
    } else {
      difficultyIndex = 1
    }

    // Reserve the trailing slots so the vector shape stays compatible with the
    // current small-model export contract (19 global features total) even
    // though this app-side encoder currently fills only the leading features.
    let global: [Float] = [
      currentPlayer == black ? 1 : 0,
      currentPlayer == white ? 1 : 0,
      capturedByBlack / 16.0,
      capturedByWhite / 16.0,
      passCount / 2.0,
      difficultyIndex / 2.0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ]

    let spatialData = NSMutableData(
      bytes: spatial,
      length: spatial.count * MemoryLayout<Float>.stride
    )
    let globalData = NSMutableData(
      bytes: global,
      length: global.count * MemoryLayout<Float>.stride
    )

    return EncodedInputs(
      spatial: try ORTValue(
        tensorData: spatialData,
        elementType: .float,
        shape: [1, NSNumber(value: planeCount), NSNumber(value: boardSize), NSNumber(value: boardSize)]
      ),
      global: try ORTValue(
        tensorData: globalData,
        elementType: .float,
        shape: [1, NSNumber(value: 19)]
      )
    )
  }

  func readFloatTensor(_ value: ORTValue) throws -> [Float] {
    let data = try value.tensorData()
    let count = data.length / MemoryLayout<Float>.stride
    var floats = [Float](repeating: 0, count: count)
    data.getBytes(&floats, length: data.length)
    return floats
  }

  func chooseMove(policy: [Float], legalMoves: [Int], boardSize: Int) -> [Int]? {
    let passIndex = boardSize * boardSize
    let candidates = legalMoves.isEmpty ? Array(0..<passIndex) : legalMoves
    var bestIndex = passIndex
    var bestScore: Float = policy.indices.contains(passIndex) ? policy[passIndex] : -.greatestFiniteMagnitude
    for moveIndex in candidates {
      guard policy.indices.contains(moveIndex) else { continue }
      let score = policy[moveIndex]
      if score > bestScore {
        bestScore = score
        bestIndex = moveIndex
      }
    }
    if bestIndex == passIndex {
      return [-1, -1]
    }
    return [bestIndex / boardSize, bestIndex % boardSize]
  }

  func computeLiberties(cells: [Int], boardSize: Int) -> [Int] {
    var result = [Int](repeating: 0, count: cells.count)
    var visited = Set<Int>()
    for index in 0..<cells.count {
      let color = cells[index]
      if color == 0 || visited.contains(index) { continue }
      var queue = [index]
      var group = Set<Int>([index])
      var liberties = Set<Int>()
      visited.insert(index)
      while let current = queue.popLast() {
        for adjacent in neighbors(of: current, boardSize: boardSize) {
          let adjacentColor = cells[adjacent]
          if adjacentColor == 0 {
            liberties.insert(adjacent)
          } else if adjacentColor == color && !group.contains(adjacent) {
            group.insert(adjacent)
            visited.insert(adjacent)
            queue.append(adjacent)
          }
        }
      }
      for point in group {
        result[point] = liberties.count
      }
    }
    return result
  }

  func adjacentOpponentCount(
    cells: [Int],
    boardSize: Int,
    index: Int,
    opponent: Int
  ) -> Int {
    neighbors(of: index, boardSize: boardSize).reduce(0) { partial, adjacent in
      partial + (cells[adjacent] == opponent ? 1 : 0)
    }
  }

  func neighbors(of index: Int, boardSize: Int) -> [Int] {
    let row = index / boardSize
    let col = index % boardSize
    var result = [Int]()
    if row > 0 { result.append(index - boardSize) }
    if row < boardSize - 1 { result.append(index + boardSize) }
    if col > 0 { result.append(index - 1) }
    if col < boardSize - 1 { result.append(index + 1) }
    return result
  }
}
#endif
