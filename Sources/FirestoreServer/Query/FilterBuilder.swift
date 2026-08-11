import Foundation

// MARK: - FilterBuilder

/// A result builder that assembles a query's filter clause declaratively.
///
/// Exactly one filter may reach the top level of the block. Two conditions written side by
/// side are two top-level filters and trap at runtime, so anything beyond a single condition
/// has to be wrapped in an explicit `And { }` or `Or { }` group. An empty block traps as well.
///
/// ## Basic usage
///
/// ```swift
/// // A single condition (the top level accepts exactly one)
/// query.filter {
///     Field("status") == "active"
/// }
///
/// // Group several conditions with And/Or
/// query.filter {
///     And {
///         Field("status") == "active"
///         Field("age") >= 18
///     }
/// }
/// ```
///
/// ## Conditional branching
///
/// `if`, `if let`, `for`, and `#available` are supported, but the block still has to end up
/// with exactly one top-level filter. The shape below traps as soon as `onlyPublished` is
/// `true`, because it then yields two — put both conditions inside `And { }` instead:
///
/// ```swift
/// query.filter {
///     Field("status") == "active"
///     if onlyPublished {
///         Field("published") == true
///     }
/// }
/// ```
///
/// ## Logical grouping
///
/// `And` and `Or` nest inside each other freely, but two groups written side by side are still
/// two top-level filters and trap the same way — one group has to contain the other:
///
/// ```swift
/// query.filter {
///     And {
///         Field("status") == "active"
///         Field("verified") == true
///     }
///     Or {
///         Field("role") == "admin"
///         Field("role") == "moderator"
///     }
/// }
/// ```
@resultBuilder
public struct FilterBuilder {
    public static func buildExpression(_ filter: FieldFilter) -> [any QueryFilterProtocol] {
        [filter]
    }

    public static func buildExpression(_ filter: UnaryFilter) -> [any QueryFilterProtocol] {
        [filter]
    }

    public static func buildExpression(_ filter: CompositeFilter) -> [any QueryFilterProtocol] {
        [filter]
    }

    public static func buildExpression(_ filter: QueryFilter) -> [any QueryFilterProtocol] {
        [filter]
    }

    public static func buildExpression(_ and: And) -> [any QueryFilterProtocol] {
        [and.filter]
    }

    public static func buildExpression(_ or: Or) -> [any QueryFilterProtocol] {
        [or.filter]
    }

    public static func buildBlock(_ components: [any QueryFilterProtocol]...) -> [any QueryFilterProtocol] {
        components.flatMap { $0 }
    }

    public static func buildBlock() -> [any QueryFilterProtocol] {
        []
    }

    public static func buildOptional(_ component: [any QueryFilterProtocol]?) -> [any QueryFilterProtocol] {
        component ?? []
    }

    public static func buildEither(first component: [any QueryFilterProtocol]) -> [any QueryFilterProtocol] {
        component
    }

    public static func buildEither(second component: [any QueryFilterProtocol]) -> [any QueryFilterProtocol] {
        component
    }

    public static func buildArray(_ components: [[any QueryFilterProtocol]]) -> [any QueryFilterProtocol] {
        components.flatMap { $0 }
    }

    public static func buildLimitedAvailability(_ component: [any QueryFilterProtocol]) -> [any QueryFilterProtocol] {
        component
    }

    /// Unwraps the block's single top-level filter.
    ///
    /// - Precondition: the block produced exactly one filter. Zero filters, or two or more of
    ///   them, trap with `fatalError` — combine them with `And { }` or `Or { }` first.
    public static func buildFinalResult(_ component: [any QueryFilterProtocol]) -> QueryFilter {
        switch component.count {
        case 0:
            fatalError("FilterBuilder requires at least one filter condition")
        case 1:
            return QueryFilter(component[0])
        default:
            fatalError("Multiple filters at top level are not allowed. Use And { } or Or { } to combine filters explicitly.")
        }
    }
}

// MARK: - And Grouping

/// An AND group of conditions, written as a block.
///
/// Produces a Firestore `compositeFilter` with `op: "AND"`. Groups nest, and Firestore
/// evaluates the resulting tree in disjunctive normal form — a query whose expansion exceeds
/// 30 disjunctions is rejected by the server.
///
/// ```swift
/// query.filter {
///     And {
///         Field("status") == "active"
///         Field("verified") == true
///     }
/// }
/// ```
public struct And: Sendable {
    /// The group as a Firestore `compositeFilter` with `op: "AND"`.
    public let filter: CompositeFilter

    /// Creates an AND group from the conditions in the block.
    /// - Parameter content: Block producing the conditions to combine. Unlike the top level of
    ///   `filter { }`, any number of conditions may sit side by side here, including none.
    public init(@AndFilterBuilder content: () -> [any QueryFilterProtocol]) {
        let filters = content()
        self.filter = CompositeFilter(
            op: .and,
            filters: filters.map { QueryFilter($0) }
        )
    }
}

/// Result builder backing `And`, which collects any number of conditions into an array.
@resultBuilder
public struct AndFilterBuilder {
    public static func buildExpression(_ filter: FieldFilter) -> [any QueryFilterProtocol] {
        [filter]
    }

    public static func buildExpression(_ filter: UnaryFilter) -> [any QueryFilterProtocol] {
        [filter]
    }

    public static func buildExpression(_ filter: CompositeFilter) -> [any QueryFilterProtocol] {
        [filter]
    }

    public static func buildExpression(_ and: And) -> [any QueryFilterProtocol] {
        [and.filter]
    }

    public static func buildExpression(_ or: Or) -> [any QueryFilterProtocol] {
        [or.filter]
    }

    public static func buildBlock(_ components: [any QueryFilterProtocol]...) -> [any QueryFilterProtocol] {
        components.flatMap { $0 }
    }

    public static func buildBlock() -> [any QueryFilterProtocol] {
        []
    }

    public static func buildOptional(_ component: [any QueryFilterProtocol]?) -> [any QueryFilterProtocol] {
        component ?? []
    }

    public static func buildEither(first component: [any QueryFilterProtocol]) -> [any QueryFilterProtocol] {
        component
    }

    public static func buildEither(second component: [any QueryFilterProtocol]) -> [any QueryFilterProtocol] {
        component
    }

    public static func buildArray(_ components: [[any QueryFilterProtocol]]) -> [any QueryFilterProtocol] {
        components.flatMap { $0 }
    }
}

// MARK: - Or Grouping

/// An OR group of conditions, written as a block.
///
/// Produces a Firestore `compositeFilter` with `op: "OR"`. Each branch of an OR is a
/// disjunction, and Firestore rejects a query whose disjunctive normal form exceeds 30 of
/// them; an OR across different fields also needs a composite index.
///
/// ```swift
/// query.filter {
///     Or {
///         Field("role") == "admin"
///         Field("role") == "moderator"
///     }
/// }
/// ```
public struct Or: Sendable {
    /// The group as a Firestore `compositeFilter` with `op: "OR"`.
    public let filter: CompositeFilter

    /// Creates an OR group from the conditions in the block.
    /// - Parameter content: Block producing the conditions to combine. Unlike the top level of
    ///   `filter { }`, any number of conditions may sit side by side here, including none.
    public init(@OrFilterBuilder content: () -> [any QueryFilterProtocol]) {
        let filters = content()
        self.filter = CompositeFilter(
            op: .or,
            filters: filters.map { QueryFilter($0) }
        )
    }
}

/// Result builder backing `Or`, which collects any number of conditions into an array.
@resultBuilder
public struct OrFilterBuilder {
    public static func buildExpression(_ filter: FieldFilter) -> [any QueryFilterProtocol] {
        [filter]
    }

    public static func buildExpression(_ filter: UnaryFilter) -> [any QueryFilterProtocol] {
        [filter]
    }

    public static func buildExpression(_ filter: CompositeFilter) -> [any QueryFilterProtocol] {
        [filter]
    }

    public static func buildExpression(_ and: And) -> [any QueryFilterProtocol] {
        [and.filter]
    }

    public static func buildExpression(_ or: Or) -> [any QueryFilterProtocol] {
        [or.filter]
    }

    public static func buildBlock(_ components: [any QueryFilterProtocol]...) -> [any QueryFilterProtocol] {
        components.flatMap { $0 }
    }

    public static func buildBlock() -> [any QueryFilterProtocol] {
        []
    }

    public static func buildOptional(_ component: [any QueryFilterProtocol]?) -> [any QueryFilterProtocol] {
        component ?? []
    }

    public static func buildEither(first component: [any QueryFilterProtocol]) -> [any QueryFilterProtocol] {
        component
    }

    public static func buildEither(second component: [any QueryFilterProtocol]) -> [any QueryFilterProtocol] {
        component
    }

    public static func buildArray(_ components: [[any QueryFilterProtocol]]) -> [any QueryFilterProtocol] {
        components.flatMap { $0 }
    }
}

// MARK: - Query Extension

extension Query {
    /// Adds a filter written with the builder DSL.
    ///
    /// The block must produce exactly one top-level filter; group anything longer with an
    /// explicit `And { }` or `Or { }`. A filter already on the query is not replaced — the two
    /// are combined with AND.
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // Single condition
    /// let activeUsers = try await schema.users.execute(
    ///     schema.users.query()
    ///         .filter {
    ///             Field("status") == "active"
    ///         }
    /// )
    ///
    /// // Several conditions, grouped explicitly with And
    /// let users = try await schema.users.execute(
    ///     schema.users.query()
    ///         .filter {
    ///             And {
    ///                 Field("status") == "active"
    ///                 Field("age") >= 18
    ///                 if onlyVerified {
    ///                     Field("verified") == true
    ///                 }
    ///             }
    ///         }
    /// )
    ///
    /// // OR condition
    /// let admins = try await schema.users.execute(
    ///     schema.users.query()
    ///         .filter {
    ///             Or {
    ///                 Field("role") == "admin"
    ///                 Field("role") == "moderator"
    ///             }
    ///         }
    /// )
    ///
    /// // Nested groups
    /// let products = try await schema.products.execute(
    ///     schema.products.query()
    ///         .filter {
    ///             And {
    ///                 Field("active") == true
    ///                 Field("stock") > 0
    ///                 Or {
    ///                     Field("category") == "electronics"
    ///                     Field("featured") == true
    ///                 }
    ///             }
    ///         }
    /// )
    /// ```
    ///
    /// - Parameter content: Block producing the filter to apply.
    public func filter(@FilterBuilder _ content: () -> QueryFilter) -> Query<T> {
        let queryFilter = content()
        return self.where(queryFilter)
    }
}
