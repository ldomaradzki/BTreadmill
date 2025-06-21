import SwiftUI
import Charts

struct SpeedChartView: View {
    let speedData: [Double]
    let height: CGFloat
    let showTitle: Bool
    
    init(speedData: [Double], height: CGFloat = 80, showTitle: Bool = false) {
        self.speedData = speedData
        self.height = height
        self.showTitle = showTitle
    }
    
    private var maxSpeed: Double {
        speedData.max() ?? 1.0
    }
    
    private var chartData: [(index: Int, speed: Double)] {
        speedData.enumerated().map { (index: $0.offset, speed: $0.element) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showTitle {
                Text("Speed Over Time")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            if speedData.isEmpty {
                // Empty state
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: height)
                    .overlay(
                        Text("No speed data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    )
            } else {
                Chart {
                    ForEach(chartData, id: \.index) { dataPoint in
                        AreaMark(
                            x: .value("Time", dataPoint.index),
                            y: .value("Speed", dataPoint.speed)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.6),
                                    Color.blue.opacity(0.2)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        LineMark(
                            x: .value("Time", dataPoint.index),
                            y: .value("Speed", dataPoint.speed)
                        )
                        .foregroundStyle(Color.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartXAxis(.hidden) // Hide X-axis labels as requested
                .chartYScale(domain: 0...(maxSpeed * 1.1)) // Scale Y-axis to max speed with 10% padding
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let speed = value.as(Double.self) {
                                Text("\(speed, specifier: "%.1f")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        AxisGridLine()
                            .foregroundStyle(Color.gray.opacity(0.3))
                        AxisTick()
                            .foregroundStyle(Color.gray.opacity(0.3))
                    }
                }
                .frame(height: height)
                .padding(.leading, 4) // Add padding for Y-axis labels
                .padding(.bottom, 4) // Add padding for bottom labels
                .background(Color(.controlBackgroundColor).opacity(0.3))
                .cornerRadius(6)
            }
            
            if showTitle && !speedData.isEmpty {
                HStack {
                    Text("Max: \(maxSpeed, specifier: "%.1f") km/h")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(speedData.count) data points")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SpeedChartView(
            speedData: [0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.2, 4.0, 3.8, 3.5, 3.0, 2.5, 2.0, 1.5, 1.0, 0.5, 0],
            height: 100,
            showTitle: true
        )
        
        SpeedChartView(
            speedData: [2.0, 2.2, 2.5, 3.0, 3.2, 3.5, 3.8, 4.0, 4.2, 4.5, 4.3, 4.0, 3.5, 3.0, 2.5, 2.0],
            height: 60,
            showTitle: false
        )
        
        SpeedChartView(
            speedData: [],
            height: 80,
            showTitle: true
        )
    }
    .padding()
}