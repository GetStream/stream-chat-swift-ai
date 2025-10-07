import SwiftUI
import Charts
internal import MarkdownUI

// MARK: - Unified Internal Model (USpec)

public enum ChartKind: String {
    case line, bar, area, scatter, bubble, pie, heatmap, histogram
}

public struct UPoint: Identifiable, Hashable {
    public var id: String { "\(x)|\(y)|\(size ?? -1)|\(z ?? -1)" }
    public let x: String           // category or stringified number/date
    public let y: Double
    public let size: Double?       // for bubble
    public let z: Double?          // for heatmap intensity
    public init(x: String, y: Double, size: Double? = nil, z: Double? = nil) {
        self.x = x; self.y = y; self.size = size; self.z = z
    }
}

public struct USeries: Identifiable {
    public let id = UUID()
    public let name: String
    public let points: [UPoint]
    public init(name: String, points: [UPoint]) { self.name = name; self.points = points }
}

public struct USpec {
    public let title: String?
    public let kind: ChartKind
    public let xLabel: String?
    public let yLabel: String?
    public let beginAtZeroY: Bool
    public let series: [USeries]
    public init(title: String?, kind: ChartKind, xLabel: String? = nil, yLabel: String? = nil, beginAtZeroY: Bool = false, series: [USeries]) {
        self.title = title; self.kind = kind; self.xLabel = xLabel; self.yLabel = yLabel; self.beginAtZeroY = beginAtZeroY; self.series = series
    }
}

// MARK: - Decoders & Adapters

private enum ParsedSpecError: Error { case unsupported }

public func parseUSpec(from jsonData: Data) throws -> USpec {
    // 1) Chart.js (+ pie/doughnut + scatter + bubble + radar/polarArea fallbacks)
    if let j = try? JSONDecoder().decode(ChartJSSpec.self, from: jsonData) {
        if let pie = mapChartJSPieIfAny(j) { return pie }
        return mapChartJSGeneral(j)
    }
    // 1b) Plotly (heatmap): single-spec and figure
    if let p = try? JSONDecoder().decode(PlotlySingleSpec.self, from: jsonData), p.type.lowercased() == "heatmap" {
        return mapPlotlySingleHeatmap(p)
    }
    if let fig = try? JSONDecoder().decode(PlotlyFigure.self, from: jsonData), let mapped = mapPlotlyFigure(fig) {
        return mapped
    }
    // 2) ECharts
    if let e = try? JSONDecoder().decode(EChartsSpec.self, from: jsonData) {
        return mapECharts(e)
    }
    // 3) Highcharts
    if let h = try? JSONDecoder().decode(HighchartsSpec.self, from: jsonData) {
        return mapHighcharts(h)
    }
    // 4) Vega-Lite (subset)
    if let v = try? JSONDecoder().decode(VegaLiteSpec.self, from: jsonData) {
        return try mapVegaLite(v)
    }
    // 5) Custom earlier schema (line/bar/area/scatter)
    if let c = try? JSONDecoder().decode(CustomSpec.self, from: jsonData) {
        return mapCustom(c)
    }
    // 6) Flat pie schema
    if let p = try? JSONDecoder().decode(PieFlatSpec.self, from: jsonData), p.type.lowercased() == "pie" {
        return mapPieFlat(p)
    }
    throw ParsedSpecError.unsupported
}

// ---------- Custom schema (from earlier) ----------
private struct CustomPoint: Decodable { let x: String; let y: Double }
private struct CustomSeries: Decodable { let name: String; let points: [CustomPoint] }
private struct CustomSpec: Decodable {
    let title: String?
    let x_label: String?
    let y_label: String?
    let chart_type: String
    let series: [CustomSeries]
}
private func mapCustom(_ c: CustomSpec) -> USpec {
    let kind = ChartKind(rawValue: c.chart_type.lowercased()) ?? .line
    let series = c.series.map { USeries(name: $0.name, points: $0.points.map { UPoint(x: $0.x, y: $0.y) }) }
    return USpec(title: c.title, kind: kind, xLabel: c.x_label, yLabel: c.y_label, beginAtZeroY: false, series: series)
}

// ---------- Flat pie ----------
private struct PieFlatItem: Decodable { let label: String; let value: Double }
private struct PieFlatSpec: Decodable { let type: String; let title: String?; let data: [PieFlatItem] }
private func mapPieFlat(_ p: PieFlatSpec) -> USpec {
    let s = USeries(name: p.title ?? "Pie", points: p.data.map { UPoint(x: $0.label, y: $0.value) })
    return USpec(title: p.title, kind: .pie, series: [s])
}

// ---------- Chart.js ----------
private struct ChartJSDatasetValue: Decodable {
    // supports number OR object {x,y,r}
    var x: Double?
    var y: Double?
    var r: Double?
    
    init(x: Double? = nil, y: Double? = nil, r: Double? = nil) {
        self.x = x
        self.y = y
        self.r = r
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let num = try? c.decode(Double.self) {
            self.x = nil; self.y = num; self.r = nil
        } else if let obj = try? c.decode([String: Double].self) {
            self.x = obj["x"]; self.y = obj["y"]; self.r = obj["r"]
        } else { self.x = nil; self.y = nil; self.r = nil }
    }
}
private struct ChartJSDataset: Decodable {
    let label: String?
    let data: [ChartJSDatasetValue]
}
private struct ChartJSData: Decodable {
    let labels: [String]?
    let datasets: [ChartJSDataset]
}
private struct ChartJSOptions: Decodable { let scales: ChartJSScales? }
private struct ChartJSScales: Decodable { let y: ChartJSScaleY? }
private struct ChartJSScaleY: Decodable { let beginAtZero: Bool? }
private struct ChartJSSpec: Decodable {
    let title: String?
    let type: String
    let data: ChartJSData
    let options: ChartJSOptions?
}

private func mapChartJSPieIfAny(_ j: ChartJSSpec) -> USpec? {
    let t = j.type.lowercased()
    guard t == "pie" || t == "doughnut" else { return nil }
    guard let ds = j.data.datasets.first else { return nil }
    let labels = j.data.labels ?? Array(0..<ds.data.count).map(String.init)
    let points: [UPoint] = zip(labels, ds.data).compactMap { (lbl, v) in
        if let y = v.y { return UPoint(x: lbl, y: y) } else { return nil }
    }
    return USpec(title: j.title, kind: .pie, series: [USeries(name: ds.label ?? "Pie", points: points)])
}

private func mapChartJSGeneral(_ j: ChartJSSpec) -> USpec {
    let type = j.type.lowercased()
    let begin0 = j.options?.scales?.y?.beginAtZero ?? false

    let series: [USeries] = j.data.datasets.map { ds in
        if let labels = j.data.labels { // arrays aligned with labels
            var pts: [UPoint] = []
            for (idx, lbl) in labels.enumerated() {
                let v = idx < ds.data.count ? ds.data[idx] : ChartJSDatasetValue(x: nil, y: nil, r: nil)
                if let y = v.y {
                    pts.append(UPoint(x: lbl, y: y, size: v.r))
                }
            }
            return USeries(name: ds.label ?? "Series", points: pts)
        } else {
            // scatter/bubble with objects {x,y,r}
            let pts = ds.data.compactMap { v -> UPoint? in
                guard let x = v.x, let y = v.y else { return nil }
                return UPoint(x: String(x), y: y, size: v.r)
            }
            return USeries(name: ds.label ?? "Series", points: pts)
        }
    }

    let kind: ChartKind = {
        switch type {
        case "line": return .line
        case "bar": return .bar
        case "area": return .area
        case "scatter": return .scatter
        case "bubble": return .bubble
        case "radar": return .bar // fallback mapping
        case "polararea": return .pie // fallback mapping
        default: return .line
        }
    }()

    return USpec(title: j.title, kind: kind, beginAtZeroY: begin0, series: series)
}

// ---------- ECharts ----------
private struct EChartsSeries: Decodable {
    let name: String?
    let type: String?
    let data: [EChartsDatum]
}
private enum EChartsDatum: Decodable {
    case number(Double)
    case pair([Double])
    case obj([String: AnyDecodable])
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let arr = try? c.decode([Double].self) { self = .pair(arr); return }
        if let obj = try? c.decode([String: AnyDecodable].self) { self = .obj(obj); return }
        self = .number(0)
    }
}
private struct EChartsSpec: Decodable { let title: TitleWrapper?; let xAxis: EAxis?; let yAxis: EAxis?; let series: [EChartsSeries] }
private struct TitleWrapper: Decodable { let text: String? }
private struct EAxis: Decodable { let data: [String]?; let type: String? }

private func mapECharts(_ e: EChartsSpec) -> USpec {
    let title = e.title?.text
    let categories = e.xAxis?.data

    var allSeries: [USeries] = []
    for s in e.series {
        let name = s.name ?? "Series"
        var pts: [UPoint] = []
        switch s.type?.lowercased() {
        case "pie":
            // ECharts pie often encodes data as [{name: "Android", value: 71.9}, ...]
            for d in s.data {
                if case .obj(let obj) = d,
                   let nameVal = obj["name"]?.string,
                   let valueVal = obj["value"]?.double {
                    pts.append(UPoint(x: nameVal, y: valueVal))
                }
            }
        default:
            if let cats = categories { // aligned arrays with xAxis.data
                for (idx, d) in s.data.enumerated() {
                    let x = idx < cats.count ? cats[idx] : String(idx)
                    switch d {
                    case .number(let v): pts.append(UPoint(x: x, y: v))
                    case .pair(let arr): if arr.count >= 2 { pts.append(UPoint(x: String(arr[0]), y: arr[1])) }
                    case .obj(let obj): if let v = obj["value"]?.double { pts.append(UPoint(x: x, y: v)) }
                    }
                }
            } else {
                for d in s.data {
                    switch d {
                    case .number(let v): pts.append(UPoint(x: String(pts.count), y: v))
                    case .pair(let arr): if arr.count >= 2 { pts.append(UPoint(x: String(arr[0]), y: arr[1])) }
                    case .obj(let obj):
                        if let v = obj["value"]?.double, let x = obj["name"]?.string ?? obj["x"]?.string { pts.append(UPoint(x: x, y: v)) }
                    }
                }
            }
        }
        allSeries.append(USeries(name: name, points: pts))
    }

    // Guess kind by first series type
    let firstType = e.series.first?.type?.lowercased()
    let kind: ChartKind = {
        switch firstType {
        case "bar": return .bar
        case "line": return .line
        case "scatter": return .scatter
        case "pie": return .pie
        default: return .line
        }
    }()

    return USpec(title: title, kind: kind, series: allSeries)
}

// ---------- Highcharts ----------
private struct HighchartsSeries: Decodable {
    let name: String?
    let type: String?
    let data: [HighchartsDatum]
}
private enum HighchartsDatum: Decodable {
    case number(Double)
    case pair([Double])
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let arr = try? c.decode([Double].self) { self = .pair(arr); return }
        self = .number(0)
    }
}
private struct HighchartsXAxis: Decodable { let categories: [String]? }
private struct HighchartsSpec: Decodable { let title: HCTitle?; let xAxis: HighchartsXAxis?; let series: [HighchartsSeries] }
private struct HCTitle: Decodable { let text: String? }

private func mapHighcharts(_ h: HighchartsSpec) -> USpec {
    let title = h.title?.text
    let categories = h.xAxis?.categories
    let series: [USeries] = h.series.map { s in
        let name = s.name ?? "Series"
        var pts: [UPoint] = []
        if let cats = categories {
            for (idx, v) in s.data.enumerated() {
                let x = idx < cats.count ? cats[idx] : String(idx)
                switch v {
                case .number(let n): pts.append(UPoint(x: x, y: n))
                case .pair(let arr): if arr.count >= 2 { pts.append(UPoint(x: String(arr[0]), y: arr[1])) }
                }
            }
        } else {
            for v in s.data {
                switch v {
                case .number(let n): pts.append(UPoint(x: String(pts.count), y: n))
                case .pair(let arr): if arr.count >= 2 { pts.append(UPoint(x: String(arr[0]), y: arr[1])) }
                }
            }
        }
        return USeries(name: name, points: pts)
    }
    let kind: ChartKind = {
        switch h.series.first?.type?.lowercased() {
        case "bar", "column": return .bar
        case "line", "spline": return .line
        case "scatter": return .scatter
        case "pie": return .pie
        default: return .line
        }
    }()
    return USpec(title: title, kind: kind, series: series)
}

// ---------- Vega-Lite (tiny subset) ----------
private struct VegaLiteSpec: Decodable {
    let schema: String? // $schema (not required here)
    let data: VegaData
    let mark: VegaMark
    let encoding: VegaEncoding
    enum CodingKeys: String, CodingKey { case schema = "$schema", data, mark, encoding }
}
private struct VegaData: Decodable { let values: [VegaRow]? }
private struct VegaRow: Decodable { let raw: [String: AnyDecodable]
    init(from decoder: Decoder) throws { let c = try decoder.singleValueContainer(); raw = (try? c.decode([String: AnyDecodable].self)) ?? [:] }
}
private enum VegaMark: Decodable { case str(String)
    init(from decoder: Decoder) throws { let c = try decoder.singleValueContainer(); let s = (try? c.decode(String.self))?.lowercased() ?? "point"; self = .str(s) }
}
private struct VegaFieldRef: Decodable { let field: String? }
private struct VegaEncoding: Decodable { let x: VegaFieldRef?; let y: VegaFieldRef?; let color: VegaFieldRef?; let size: VegaFieldRef? }

private func mapVegaLite(_ v: VegaLiteSpec) throws -> USpec {
    guard let rows = v.data.values else { throw ParsedSpecError.unsupported }
    let xField = v.encoding.x?.field ?? "x"
    let yField = v.encoding.y?.field ?? "y"
    let colorField = v.encoding.color?.field
    let sizeField = v.encoding.size?.field

    // Group by colorField into series
    var groups: [String: [UPoint]] = [:]
    for r in rows {
        let xStr = r.raw[xField]?.string ?? String(r.raw[xField]?.double ?? 0)
        let yVal = r.raw[yField]?.double ?? 0
        let key = colorField.flatMap { r.raw[$0]?.string } ?? "Series"
        let sizeVal = sizeField.flatMap { r.raw[$0]?.double }
        groups[key, default: []].append(UPoint(x: xStr, y: yVal, size: sizeVal))
    }

    let series = groups.map { USeries(name: $0.key, points: $0.value) }

    // Determine kind from mark
    let kind: ChartKind = {
        if case let .str(s) = v.mark {
            switch s {
            case "line": return .line
            case "bar": return .bar
            case "area": return .area
            case "point": return .scatter
            case "rect": return .heatmap
            default: return .line
            }
        } else { return .line }
    }()

    return USpec(title: nil, kind: kind, series: series)
}

// ---------- Plotly (heatmap) ----------
private struct PlotlyLayoutAxisTitle: Decodable {
    let text: String?
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { text = s }
        else if let obj = try? c.decode([String:String].self) { text = obj["text"] }
        else { text = nil }
    }
}
private struct PlotlyAxis: Decodable { let title: PlotlyLayoutAxisTitle? }
private struct PlotlyLayout: Decodable { let title: PlotlyLayoutAxisTitle?; let xaxis: PlotlyAxis?; let yaxis: PlotlyAxis? }
private struct PlotlyHeatmapDataSingle: Decodable { let z: [[Double]]; let x: [String]?; let y: [String]? }
private struct PlotlySingleSpec: Decodable { let type: String; let data: PlotlyHeatmapDataSingle; let layout: PlotlyLayout? }
private struct PlotlyTrace: Decodable { let type: String?; let z: [[Double]]?; let x: [String]?; let y: [String]?; let name: String? }
private struct PlotlyFigure: Decodable { let data: [PlotlyTrace]; let layout: PlotlyLayout? }

private func mapPlotlySingleHeatmap(_ p: PlotlySingleSpec) -> USpec {
    let z = p.data.z
    let xCats = p.data.x ?? (z.first?.indices.map { String($0) } ?? [])
    let yCats = p.data.y ?? z.indices.map { String($0) }
    var series: [USeries] = []
    for (i, row) in z.enumerated() {
        let yName = i < yCats.count ? yCats[i] : String(i)
        var pts: [UPoint] = []
        for (j, val) in row.enumerated() {
            let xName = j < xCats.count ? xCats[j] : String(j)
            pts.append(UPoint(x: xName, y: 0, z: val))
        }
        series.append(USeries(name: yName, points: pts))
    }
    return USpec(title: p.layout?.title?.text,
                 kind: .heatmap,
                 xLabel: p.layout?.xaxis?.title?.text,
                 yLabel: p.layout?.yaxis?.title?.text,
                 beginAtZeroY: false,
                 series: series)
}

private func mapPlotlyFigure(_ f: PlotlyFigure) -> USpec? {
    guard let trace = f.data.first(where: { ($0.type?.lowercased() == "heatmap") && $0.z != nil }) else { return nil }
    let z = trace.z!
    let xCats = trace.x ?? (z.first?.indices.map { String($0) } ?? [])
    let yCats = trace.y ?? z.indices.map { String($0) }
    var series: [USeries] = []
    for (i, row) in z.enumerated() {
        let yName = i < yCats.count ? yCats[i] : String(i)
        var pts: [UPoint] = []
        for (j, val) in row.enumerated() {
            let xName = j < xCats.count ? xCats[j] : String(j)
            pts.append(UPoint(x: xName, y: 0, z: val))
        }
        series.append(USeries(name: yName, points: pts))
    }
    return USpec(title: f.layout?.title?.text,
                 kind: .heatmap,
                 xLabel: f.layout?.xaxis?.title?.text,
                 yLabel: f.layout?.yaxis?.title?.text,
                 beginAtZeroY: false,
                 series: series)
}

// ---------- AnyDecodable helper ----------
public struct AnyDecodable: Decodable {
    public let value: Any
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Double.self) { value = v; return }
        if let v = try? c.decode(Int.self) { value = Double(v); return }
        if let v = try? c.decode(String.self) { value = v; return }
        if let v = try? c.decode(Bool.self) { value = v; return }
        if let v = try? c.decode([String: AnyDecodable].self) { value = v; return }
        if let v = try? c.decode([AnyDecodable].self) { value = v; return }
        value = NSNull()
    }
    public var string: String? { value as? String }
    public var double: Double? {
        if let d = value as? Double { return d }
        if let b = value as? Bool { return b ? 1 : 0 }
        return value as? Double
    }
}

// MARK: - Renderer

@available(iOS 16.0, *)
public struct USpecChartView: View {
    public let spec: USpec
    public init(spec: USpec) { self.spec = spec }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = spec.title { Text(title).font(.headline) }
            
            switch spec.kind {
            case .pie:
                PieChart(spec: spec).frame(height: 280)
                
            case .heatmap:
                HeatmapChart(spec: spec).frame(height: 280)
                
            case .histogram:
                HistogramChart(spec: spec).frame(height: 280)
                
            case .bubble:
                Chart {
                    ForEach(spec.series) { s in
                        ForEach(s.points) { p in
                            if #available(iOS 17.0, *), let r = p.size {
                                // iOS 17: data-driven size
                                PointMark(
                                    x: .value(spec.xLabel ?? "X", p.x),
                                    y: .value(spec.yLabel ?? "Y", p.y)
                                )
                                .symbolSize(by: .value("Size", r))
                                .foregroundStyle(by: .value("Series", s.name))
                            } else if let r = p.size {
                                // iOS 16: use a fixed numeric size (coarse fallback)
                                PointMark(
                                    x: .value(spec.xLabel ?? "X", p.x),
                                    y: .value(spec.yLabel ?? "Y", p.y)
                                )
                                .symbolSize(CGFloat(max(6, min(80, r))))
                                .foregroundStyle(by: .value("Series", s.name))
                            } else {
                                // no size provided
                                PointMark(
                                    x: .value(spec.xLabel ?? "X", p.x),
                                    y: .value(spec.yLabel ?? "Y", p.y)
                                )
                                .foregroundStyle(by: .value("Series", s.name))
                            }
                        }
                    }
                }
                .applyBeginAtZero(spec.beginAtZeroY)
                .frame(height: 280)
                
            case .scatter, .line, .bar, .area:
                Chart {
                    ForEach(spec.series) { s in
                        switch spec.kind {
                        case .bar:
                            ForEach(s.points) { p in
                                BarMark(x: .value(spec.xLabel ?? "X", p.x),
                                        y: .value(spec.yLabel ?? "Y", p.y))
                                .foregroundStyle(by: .value("Series", s.name))
                            }
                        case .area:
                            ForEach(s.points) { p in
                                AreaMark(x: .value(spec.xLabel ?? "X", p.x),
                                         y: .value(spec.yLabel ?? "Y", p.y))
                                .foregroundStyle(by: .value("Series", s.name))
                            }
                        case .line:
                            ForEach(s.points) { p in
                                LineMark(x: .value(spec.xLabel ?? "X", p.x),
                                         y: .value(spec.yLabel ?? "Y", p.y))
                                .foregroundStyle(by: .value("Series", s.name))
                            }
                        default: // scatter
                            ForEach(s.points) { p in
                                PointMark(x: .value(spec.xLabel ?? "X", p.x),
                                          y: .value(spec.yLabel ?? "Y", p.y))
                                .foregroundStyle(by: .value("Series", s.name))
                            }
                        }
                    }
                }
                .applyBeginAtZero(spec.beginAtZeroY)
                .frame(height: 280)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Specialized charts

// Pie / Donut
private struct PieDatum: Identifiable { let id = UUID(); let label: String; let value: Double; let pct: Double }
private func pieData(from spec: USpec) -> [PieDatum] {
    let pts = spec.series.first?.points ?? []
    let total = max(pts.reduce(0) { $0 + $1.y }, 0.000001)
    return pts.map { PieDatum(label: $0.x, value: $0.y, pct: $0.y / total) }
}

private struct PieChart: View {
    let spec: USpec
    var body: some View {
        let data = pieData(from: spec)
        Group {
            if #available(iOS 17.0, *) {
                Chart(data) { d in
                    SectorMark(angle: .value("Value", d.value), innerRadius: .ratio(0.0), angularInset: 1)
                        .foregroundStyle(by: .value("Category", d.label))
                        .annotation(position: .overlay, alignment: .center) {
                            if d.pct >= 0.08 { Text("\(d.label) \(Int(round(d.pct * 100)))%") .font(.caption2).bold() }
                        }
                }
                .chartLegend(.visible)
            }
        }
    }
}

// Heatmap (x category, y series.name or y extracted from point.x if encoded)
@available(iOS 16.0, *)
private struct HeatmapChart: View {
    let spec: USpec
    var body: some View {
        Chart {
            ForEach(spec.series) { s in
                ForEach(s.points) { p in
                    RectangleMark(
                        x: .value("X", p.x),
                        y: .value("Y", s.name),
                        width: .ratio(1.0), height: .ratio(1.0)
                    )
                    .foregroundStyle(by: .value("Value", p.z ?? p.y))
                }
            }
        }
    }
}

// Histogram: expects one series with raw values in y; we bin in 10 buckets
@available(iOS 16.0, *)
private struct HistogramChart: View {
    let spec: USpec
    var body: some View {
        let raw = spec.series.first?.points.map { $0.y } ?? []
        let bins = makeBins(raw, targetBins: 10)
        Chart(bins) { b in
            BarMark(x: .value("Bin", b.label), y: .value("Count", b.count))
        }
    }
}
private struct Bin: Identifiable { let id = UUID(); let label: String; let count: Int }
private func makeBins(_ values: [Double], targetBins: Int) -> [Bin] {
    guard let minV = values.min(), let maxV = values.max(), maxV > minV else { return [] }
    let bins = max(targetBins, 1)
    let step = (maxV - minV) / Double(bins)
    var counts = Array(repeating: 0, count: bins)
    for v in values { let idx = min(Int((v - minV) / step), bins - 1); counts[idx] += 1 }
    return counts.enumerated().map { i, c in Bin(label: String(format: "%.1f–%.1f", minV + Double(i)*step, minV + Double(i+1)*step), count: c) }
}

// MARK: - View helpers
private func colorForIndex(_ i: Int) -> Color {
    let colors: [Color] = [.blue, .green, .orange, .pink, .purple, .teal, .red, .indigo, .mint, .brown]
    return colors[i % colors.count]
}

@available(iOS 16.0, *)
private extension View {
    @ViewBuilder func applyBeginAtZero(_ include: Bool) -> some View {
        self.chartYScale(domain: include ? .automatic(includesZero: true) : .automatic(includesZero: false))
    }
}
