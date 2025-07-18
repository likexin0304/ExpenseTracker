import Foundation
import SwiftUI
import Combine

/**
 * 状态管理系统 - 实现单向数据流
 * 提供清晰的状态变更路径，减少副作用和不可预测的状态变化
 */

// MARK: - 核心协议

/// 状态变更动作协议
public protocol Action {
    /// 动作的唯一标识符
    var id: String { get }
}

/// 状态协议
public protocol AppState {
    /// 状态的唯一标识符
    var id: String { get }
}

/// 状态变更处理器
public protocol Reducer {
    associatedtype StateType: AppState
    associatedtype ActionType: Action
    
    /// 处理状态变更
    /// - Parameters:
    ///   - state: 当前状态
    ///   - action: 触发的动作
    /// - Returns: 新的状态
    func reduce(state: StateType, action: ActionType) -> StateType
}

// MARK: - 状态存储

/// 状态存储
public class Store<R: Reducer> {
    public typealias StateType = R.StateType
    public typealias ActionType = R.ActionType
    
    /// 当前状态
    @Published public private(set) var state: StateType
    
    /// 状态变更处理器
    private let reducer: R
    
    /// 状态变更中间件
    private var middlewares: [(StateType, ActionType, @escaping (ActionType) -> Void) -> Void] = []
    
    /// 状态变更锁
    private var isDispatching = false
    
    /// 初始化状态存储
    /// - Parameters:
    ///   - initialState: 初始状态
    ///   - reducer: 状态变更处理器
    public init(initialState: StateType, reducer: R) {
        self.state = initialState
        self.reducer = reducer
    }
    
    /// 添加中间件
    /// - Parameter middleware: 中间件闭包
    public func addMiddleware(_ middleware: @escaping (StateType, ActionType, @escaping (ActionType) -> Void) -> Void) {
        middlewares.append(middleware)
    }
    
    /// 分发动作
    /// - Parameter action: 要分发的动作
    public func dispatch(_ action: ActionType) {
        // 防止递归分发
        guard !isDispatching else {
            print("⚠️ 警告: 在状态变更过程中尝试分发新的动作，已忽略")
            return
        }
        
        // 应用中间件
        for middleware in middlewares {
            middleware(state, action) { [weak self] nextAction in
                self?.dispatch(nextAction)
            }
        }
        
        // 设置分发锁
        isDispatching = true
        
        // 应用状态变更
        let newState = reducer.reduce(state: state, action: action)
        
        // 更新状态
        state = newState
        
        // 释放分发锁
        isDispatching = false
    }
}

/// 状态绑定
extension Store {
    /// 创建状态绑定
    /// - Parameter keyPath: 状态属性的键路径
    /// - Returns: 绑定
    public func binding<Value>(for keyPath: KeyPath<StateType, Value>) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { _ in
                // 单向数据流中，不允许直接设置状态
                // 必须通过分发动作来修改状态
                print("⚠️ 警告: 尝试直接修改状态，在单向数据流中这是不允许的")
            }
        )
    }
}

// MARK: - 中间件

/// 防抖中间件
public func createDebounceMiddleware<S: AppState, A: Action>(
    for actionTypes: [String],
    interval: TimeInterval = 0.3
) -> (S, A, @escaping (A) -> Void) -> Void {
    var lastActionTime: [String: Date] = [:]
    
    return { _, action, next in
        // 如果动作类型在需要防抖的列表中
        if actionTypes.contains(action.id) {
            let now = Date()
            if let lastTime = lastActionTime[action.id],
               now.timeIntervalSince(lastTime) < interval {
                // 忽略过于频繁的动作
                return
            }
            lastActionTime[action.id] = now
        }
        
        // 执行下一个中间件或reducer
        next(action)
    }
} 