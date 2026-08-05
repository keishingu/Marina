import XCTest
@testable import Marina

final class DockerInspectParserTests: XCTestCase {
    func test_DockerPSのJSON行からIDを取得する() throws {
        let data = Data("{\"ID\":\"abcdef123456\",\"Names\":\"marina-web-1\"}\n{\"ID\":\"123456abcdef\"}\n".utf8)
        XCTAssertEqual(try DockerInspectParser().parsePSIdentifiers(data), ["abcdef123456", "123456abcdef"])
    }

    func test_inspectからComposeラベルと複数ポートを取得する() throws {
        let containers = try DockerInspectParser().parseInspect(Data(Self.inspectJSON.utf8))

        XCTAssertEqual(containers.count, 1)
        XCTAssertEqual(containers[0].name, "marina-web-1")
        XCTAssertEqual(containers[0].image, "marina-web:latest")
        XCTAssertEqual(containers[0].compose.project, "marina")
        XCTAssertEqual(containers[0].compose.service, "web")
        XCTAssertEqual(containers[0].compose.containerNumber, "1")
        XCTAssertEqual(containers[0].compose.workingDirectory, "/project")
        XCTAssertEqual(containers[0].compose.configFiles, "/project/compose.yml")
        XCTAssertEqual(containers[0].portMappings.count, 2)
        XCTAssertEqual(containers[0].portMappings.map(\.hostPort), [3_000, 9_229])
        XCTAssertEqual(containers[0].portMappings.map(\.containerPort), [3_000, 9_229])
    }

    func test_不正JSONは解析エラーにする() {
        XCTAssertThrowsError(try DockerInspectParser().parseInspect(Data("not-json".utf8))) { error in
            XCTAssertTrue(error is DockerParsingError)
        }
    }

    static let inspectJSON = """
    [{
      "Id": "abcdef123456abcdef123456abcdef123456abcdef123456abcdef123456abcd",
      "Name": "/marina-web-1",
      "Config": {
        "Image": "marina-web:latest",
        "Labels": {
          "com.docker.compose.project": "marina",
          "com.docker.compose.service": "web",
          "com.docker.compose.container-number": "1",
          "com.docker.compose.project.working_dir": "/project",
          "com.docker.compose.project.config_files": "/project/compose.yml"
        }
      },
      "State": { "Status": "running" },
      "NetworkSettings": {
        "Ports": {
          "3000/tcp": [{ "HostIp": "127.0.0.1", "HostPort": "3000" }],
          "9229/tcp": [{ "HostIp": "0.0.0.0", "HostPort": "9229" }]
        }
      }
    }]
    """
}
