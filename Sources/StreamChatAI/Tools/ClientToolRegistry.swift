//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import Foundation
import MCP

public protocol ClientToolActionHandling: AnyObject {
    func handle(_ actions: [ClientToolAction])
}

public final class ClientToolRegistry {
    private var toolsByName: [String: any ClientTool] = [:]

    public init() {}

    public func register(tool: any ClientTool) {
        toolsByName[tool.toolDefinition.name] = tool
    }

    public func registrationPayloads() -> [ToolRegistrationPayload] {
        toolsByName.values.map { tool in
            ToolRegistrationPayload(
                name: tool.toolDefinition.name,
                description: tool.toolDefinition.description ?? tool.instructions,
                instructions: tool.instructions,
                parameters: tool.toolDefinition.inputSchema,
                showExternalSourcesIndicator: tool.showExternalSourcesIndicator
            )
        }
    }

    public func handleInvocation(_ invocation: ClientToolInvocation) -> [ClientToolAction] {
        guard let tool = toolsByName[invocation.tool.name] else { return [] }
        return tool.handleInvocation(invocation)
    }
}

public protocol ClientTool: AnyObject {
    var toolDefinition: Tool { get }
    var instructions: String { get }
    var showExternalSourcesIndicator: Bool { get }

    func handleInvocation(_ invocation: ClientToolInvocation) -> [ClientToolAction]
}

public struct ClientToolInvocation {
    public struct ToolDescriptor {
        let name: String
        let description: String?
        let instructions: String?
        let parameters: Data?

        public init(
            name: String,
            description: String?,
            instructions: String?,
            parameters: Data?
        ) {
            self.name = name
            self.description = description
            self.instructions = instructions
            self.parameters = parameters
        }
    }

    public let tool: ToolDescriptor
    public let args: Data?
    public let messageId: String?
    public let channelId: AnyHashable?

    public init(
        tool: ToolDescriptor,
        args: Data?,
        messageId: String?,
        channelId: AnyHashable?
    ) {
        self.tool = tool
        self.args = args
        self.messageId = messageId
        self.channelId = channelId
    }
}

public typealias ClientToolAction = () -> Void

public struct ToolRegistrationPayload: Encodable {
    public let name: String
    public let description: String
    public let instructions: String?
    public let parameters: Value?
    public let showExternalSourcesIndicator: Bool?
}
