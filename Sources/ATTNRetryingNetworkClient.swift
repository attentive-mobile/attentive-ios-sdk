//
//  ATTNRetryingNetworkClient.swift
//  attentive-ios-sdk-framework
//
//  Created by Adela Gao on 5/30/25.
//

import Foundation

/// Configuration for retry behavior.
struct ATTNRetryConfiguration {
    /// Base delay before first retry.
    let initialDelay: TimeInterval
    /// Maximum number of retry attempts.
    let maxRetries: Int
    /// Jitter range (seconds) to randomize each backoff delay.
    let jitterRange: ClosedRange<Double>
    /// Cap on total cumulative retry delay
    let maxCumulativeDelay: TimeInterval

    init(
        initialDelay: TimeInterval = 1.0,
        maxRetries: Int = 5,
        jitterRange: ClosedRange<Double> = -0.5...0.5,
        maxCumulativeDelay: TimeInterval = 300.0 // 5 minutes
    ) {
        self.initialDelay = initialDelay
        self.maxRetries = maxRetries
        self.jitterRange = jitterRange
        self.maxCumulativeDelay = maxCumulativeDelay
    }
}

/// A lightweight retrying client that:
///  Retries on URLError (timeouts, no network, etc.)
///  Retries on HTTP 429 (rate limiting) or 5xx (server errors)
///  Honors “Retry-After” header if provided
///  Uses exponential backoff + jitter
///  Stops once maxRetries or maxCumulativeDelay is exceeded
final class ATTNRetryingNetworkClient {
    private let session: URLSession
    private let config: ATTNRetryConfiguration
    /// A dedicated queue for scheduling retries (instead of using `DispatchQueue.global`).
    private let retryQueue = DispatchQueue(
        label: "com.attentive.retryQueue",
        qos: .utility,
        attributes: .concurrent
    )

    init(
        session: URLSession = .shared,
        config: ATTNRetryConfiguration = ATTNRetryConfiguration()
    ) {
        self.session = session
        self.config = config
    }

    func performRequestWithRetry(
        _ request: URLRequest,
        to url: URL,
        callback: ATTNAPICallback?
    ) {
        // Schedule the first attempt on our dedicated retryQueue
        retryQueue.async {
            self.attempt(
                request: request,
                url: url,
                attemptCount: 0,
                cumulativeDelay: 0,
                callback: callback
            )
        }
    }

    private func attempt(
        request: URLRequest,
        url: URL,
        attemptCount: Int,
        cumulativeDelay: TimeInterval,
        callback: ATTNAPICallback?
    ) {
        Loggers.network.debug("Attempt \(attemptCount + 1, privacy: .public) → \(url, privacy: .public)")

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 200

            let isNetworkError = (error as? URLError) != nil

            // Determine if HTTP code is retryable: 429 or 5xx
            let isRetryableHTTP = (statusCode == 429) || (500...599).contains(statusCode)

            let shouldRetry = (isNetworkError || isRetryableHTTP) && (attemptCount < self.config.maxRetries)

            if shouldRetry {
                // If server sent "Retry-After", use that. Otherwise compute exponential+jitters.
                let backoff: TimeInterval
                if statusCode == 429, let retryAfter = self.parseRetryAfter(httpResponse) {
                    backoff = retryAfter
                } else {
                    backoff = self.computeBackoff(for: attemptCount)
                }
                let nextCumulative = cumulativeDelay + backoff

                if nextCumulative > self.config.maxCumulativeDelay {
                    Loggers.network.error(
                        "Exceeded max cumulative delay (\(self.config.maxCumulativeDelay, privacy: .public)s). Aborting retries."
                    )
                    DispatchQueue.main.async {
                        callback?(data, url, response, error)
                    }
                } else {
                    Loggers.network.error("retrying soon with backoff: \(backoff, privacy: .public)")
                    Loggers.network.error(
                        "Failed (status \(statusCode, privacy: .public), error: \(error?.localizedDescription ?? "–", privacy: .public)) Retrying in \(String(format: "%.2fs", backoff), privacy: .public)…"
                    )
                    // Schedule the next retry on retryQueue
                    retryQueue.asyncAfter(deadline: .now() + backoff) { [weak self] in
                        guard let self = self else { return }
                        self.attempt(
                            request: request,
                            url: url,
                            attemptCount: attemptCount + 1,
                            cumulativeDelay: nextCumulative,
                            callback: callback
                        )
                    }
                }
            } else {
                if isNetworkError || isRetryableHTTP {
                    Loggers.network.error(
                        "Permanent failure after \(attemptCount + 1, privacy: .public) attempts (status \(statusCode, privacy: .public))."
                    )
                } else {
                    Loggers.network.debug("Success on attempt \(attemptCount + 1, privacy: .public)")
                }
                DispatchQueue.main.async {
                    callback?(data, url, response, error)
                }
            }
        }

        task.resume()
    }

    /// Exponential backoff + random jitter:
    ///   delay = initialDelay * (2^attemptCount) + random(jitterRange)
    private func computeBackoff(for attemptCount: Int) -> TimeInterval {
        let exponential = config.initialDelay * pow(2.0, Double(attemptCount))
        var rng = SystemRandomNumberGenerator()
        let jitter = Double.random(in: config.jitterRange, using: &rng)
        return max(0, exponential + jitter)
    }

    /// If the server sends a "Retry-After" header, parse it as either:
    ///  • A number of seconds, or
    ///  • An RFC-1123 date string.
    /// Otherwise return nil.
    private func parseRetryAfter(_ response: HTTPURLResponse?) -> TimeInterval? {
        guard let header = response?.value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }
        if let seconds = TimeInterval(header) {
            return seconds
        }
        // Use a shared static DateFormatter for thread safety & performance
        if let date = ATTNRetryingNetworkClient.retryAfterDateFormatter.date(from: header) {
            let interval = date.timeIntervalSinceNow
            return interval > 0 ? interval : 0
        }
        return nil
    }

    /// A single shared DateFormatter for parsing RFC-1123 "Retry-After" dates.
    private static let retryAfterDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US")
        df.dateFormat = "EEE',' dd MMM yyyy HH:mm:ss zzz"
        return df
    }()
}
