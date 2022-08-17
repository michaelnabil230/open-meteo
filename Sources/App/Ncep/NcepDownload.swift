import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes


enum NcepDomain: String {
    case gfs025
    
    var omfileDirectory: String {
        return "./data/omfile-\(rawValue)/"
    }
    var downloadDirectory: String {
        return "./data/\(rawValue)/"
    }
    var omfileArchive: String? {
        return nil
    }
    
    var dtSeconds: Int {
        return 3600
    }
    
    var elevationFile: OmFileReader? {
        return nil
    }
    
    var forecastHours: [Int] {
        switch self {
        case .gfs025:
            return Array(stride(from: 0, to: 120, by: 1)) + Array(stride(from: 120, through: 384, by: 3))
        }
    }
    
    var omFileLength: Int {
        switch self {
        case .gfs025:
            return 384 + 1 + 4*24
        }
    }
    
    var grid: RegularGrid {
        switch self {
        case .gfs025:
            return RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        }
    }
}


enum GfsVariable: String, CurlIndexedVariable, CaseIterable {
    case temperature_2m
    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case pressure_msl
    case relativehumidity_2m
    
    /// accumulated since forecast start
    case precipitation
    
    case v_10m
    case u_10m
    case v_80m
    case u_80m
    
    case soil_temperature_0_to_10cm
    case soil_temperature_10_to_40cm
    case soil_temperature_40_to_100cm
    case soil_temperature_100_to_200cm
    
    case soil_moisture_0_to_10cm
    case soil_moisture_10_to_40cm
    case soil_moisture_40_to_100cm
    case soil_moisture_100_to_200cm
    
    case snow_depth
    
    /// averaged since model start
    case sensible_heatflux
    case latent_heatflux
    
    case showers
    //case rain
    //case snowfall_convective_water_equivalent
    //case snowfall_water_equivalent
    
    case windgusts_10m
    case freezinglevel_height
    case shortwave_radiation
    // diff could be estimated with https://arxiv.org/pdf/2007.01639.pdf 3) method
    //case diffuse_radiation
    //case direct_radiation
    
    var omFileName: String {
        return rawValue
    }
    
    var skipHour0: Bool {
        switch self {
        case .precipitation: return true
        case .sensible_heatflux: return true
        case .latent_heatflux: return true
        case .showers: return true
        case .shortwave_radiation: return true
        default: return false
        }
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m: return 20
        case .cloudcover: return 1
        case .cloudcover_low: return 1
        case .cloudcover_mid: return 1
        case .cloudcover_high: return 1
        case .relativehumidity_2m: return 1
        case .precipitation: return 10
        case .v_10m: return 10
        case .u_10m: return 10
        case .v_80m: return 10
        case .u_80m: return 10
        case .soil_temperature_0_to_10cm: return 20
        case .soil_temperature_10_to_40cm: return 20
        case .soil_temperature_40_to_100cm: return 20
        case .soil_temperature_100_to_200cm: return 20
        case .soil_moisture_0_to_10cm: return 1000
        case .soil_moisture_10_to_40cm: return 1000
        case .soil_moisture_40_to_100cm: return 1000
        case .soil_moisture_100_to_200cm: return 1000
        case .snow_depth: return 100 // 1cm res
        case .sensible_heatflux: return 0.144
        case .latent_heatflux: return 0.144 // round watts to 7.. results in 0.01 resolution in evpotrans
        case .windgusts_10m: return 10
        case .freezinglevel_height:  return 0.1 // zero height 10 meter resolution
        case .showers: return 10
        case .pressure_msl: return 10
        case .shortwave_radiation: return 1
        }
    }
    
    /// unit stored on disk... or directly read by low level reads
    var unit: SiUnit {
        switch self {
        case .temperature_2m: return .celsius
        case .cloudcover: return .percent
        case .cloudcover_low: return .percent
        case .cloudcover_mid: return .percent
        case .cloudcover_high: return .percent
        case .relativehumidity_2m: return .percent
        case .precipitation: return .millimeter
        case .v_10m: return .ms
        case .u_10m: return .ms
        case .v_80m: return .ms
        case .u_80m: return .ms
        case .soil_temperature_0_to_10cm: return .celsius
        case .soil_temperature_10_to_40cm: return .celsius
        case .soil_temperature_40_to_100cm: return .celsius
        case .soil_temperature_100_to_200cm: return .celsius
        case .soil_moisture_0_to_10cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_10_to_40cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_40_to_100cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_100_to_200cm: return .qubicMeterPerQubicMeter
        case .snow_depth: return .meter
        case .sensible_heatflux: return .wattPerSquareMeter
        case .latent_heatflux: return .wattPerSquareMeter
        case .showers: return .millimeter
        case .windgusts_10m: return .ms
        case .freezinglevel_height: return .meter
        case .pressure_msl: return .hectoPascal
        case .shortwave_radiation: return .wattPerSquareMeter
        }
    }
    
    var isAveragedOverForecastTime: Bool {
        switch self {
        case .shortwave_radiation: return true
        case .sensible_heatflux: return true
        case .latent_heatflux: return true
        default: return false
        }
    }
    
    /// Soil moisture or snow depth are cumulative processes and have offests if mutliple models are mixed
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .soil_moisture_0_to_10cm: return true
        case .soil_moisture_10_to_40cm: return true
        case .soil_moisture_40_to_100cm: return true
        case .soil_moisture_100_to_200cm: return true
        case .snow_depth: return true
        default: return false
        }
    }
    
    var interpolationType: InterpolationType {
        switch self {
        case .temperature_2m: return .hermite
        case .cloudcover: return .hermite
        case .cloudcover_low: return .hermite
        case .cloudcover_mid: return .hermite
        case .cloudcover_high: return .hermite
        case .relativehumidity_2m: return .hermite
        case .precipitation: return .linear
        case .v_10m: return .hermite
        case .u_10m: return .hermite
        case .snow_depth: return .linear
        case .sensible_heatflux: return .hermite_backwards_averaged
        case .latent_heatflux: return .hermite_backwards_averaged
        case .windgusts_10m: return .linear
        case .freezinglevel_height: return .hermite
        case .shortwave_radiation: return .solar_backwards_averaged
        case .soil_temperature_0_to_10cm: return .hermite
        case .soil_temperature_10_to_40cm: return .hermite
        case .soil_temperature_40_to_100cm: return .hermite
        case .soil_temperature_100_to_200cm: return .hermite
        case .soil_moisture_0_to_10cm: return .hermite
        case .soil_moisture_10_to_40cm: return .hermite
        case .soil_moisture_40_to_100cm: return .hermite
        case .soil_moisture_100_to_200cm: return .hermite
        case .v_80m: return .hermite
        case .u_80m: return .hermite
        case .showers: return .linear
        case .pressure_msl: return .hermite
        }
    }
    
    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .precipitation: fallthrough
        case .showers: return true
        default: return false
        }
    }
    
    var gribIndexName: String {
        switch self {
        case .temperature_2m:
            return ":TMP:2 m above ground:"
        case .cloudcover:
            return ":TCDC:entire atmosphere:"
        case .cloudcover_low:
            return ":LCDC:low cloud layer:"
        case .cloudcover_mid:
            return ":MCDC:middle cloud layer:"
        case .cloudcover_high:
            return ":HCDC:high cloud layer:"
        case .pressure_msl:
            return ":PRMSL:mean sea level:"
        case .relativehumidity_2m:
            return ":RH:2 m above ground:"
        case .precipitation:
            return ":APCP:surface:0-"
        case .v_10m:
            return ":VGRD:10 m above ground:"
        case .u_10m:
            return ":UGRD:10 m above ground:"
        case .v_80m:
            return ":VGRD:80 m above ground:"
        case .u_80m:
            return ":UGRD:80 m above ground:"
        case .soil_temperature_0_to_10cm:
            return ":TSOIL:0-0.1 m below ground:"
        case .soil_temperature_10_to_40cm:
            return ":TSOIL:0.1-0.4 m below ground:"
        case .soil_temperature_40_to_100cm:
            return ":TSOIL:0.4-1 m below ground:"
        case .soil_temperature_100_to_200cm:
            return ":TSOIL:1-2 m below ground:"
        case .soil_moisture_0_to_10cm:
            return ":SOILW:0-0.1 m below ground:"
        case .soil_moisture_10_to_40cm:
            return ":SOILW:0.1-0.4 m below ground:"
        case .soil_moisture_40_to_100cm:
            return ":SOILW:0.4-1 m below ground:"
        case .soil_moisture_100_to_200cm:
            return ":SOILW:1-2 m below ground:"
        case .snow_depth:
            return ":SNOD:surface:"
        case .sensible_heatflux:
            return ":SHTFL:surface:"
        case .latent_heatflux:
            return ":LHTFL:surface:"
        case .showers:
            return ":ACPCP:surface:0-"
        case .windgusts_10m:
            return ":GUST:surface:"
        case .freezinglevel_height:
            return ":HGT:0C isotherm:"
        case .shortwave_radiation:
            return ":DSWRF:surface:"
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m:
            return (1, -273.15)
        case .pressure_msl:
            return (1, 1/100)
        case .soil_temperature_0_to_10cm:
            return (1, -273.15)
        case .soil_temperature_10_to_40cm:
            return (1, -273.15)
        case .soil_temperature_40_to_100cm:
            return (1, -273.15)
        case .soil_temperature_100_to_200cm:
            return (1, -273.15)
        default:
            return nil
        }
    }
}


/**
NCEP GFS downloader
 */
struct NcepDownload: Command {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Flag(name: "skip-existing")
        var skipExisting: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
    }

    var help: String {
        "Download GFS from NOAA NCEP"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let logger = context.application.logger
        guard let domain = NcepDomain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        switch domain {
        case .gfs025:
            let run = signature.run.map {
                guard let run = Int($0) else {
                    fatalError("Invalid run '\($0)'")
                }
                return run
            } ?? ((Timestamp.now().hour - 2 + 24) % 24 ).floor(to: 6)
            
            let variables: [GfsVariable] = signature.onlyVariables.map {
                $0.split(separator: ",").map {
                    guard let variable = GfsVariable(rawValue: String($0)) else {
                        fatalError("Invalid variable '\($0)'")
                    }
                    return variable
                }
            } ?? GfsVariable.allCases
            
            /// 18z run is available the day after starting 05:26
            let date = Timestamp.now().with(hour: run)
            
            try downloadGfs(logger: logger, domain: domain, run: date, variables: variables, skipFilesIfExisting: signature.skipExisting)
            try convertGfs(logger: logger, domain: domain, variables: variables, run: date)
        }
    }
    
    /// download cfs domain
    /*func downloadCfsElevation(logger: Logger, domain: SeasonalForecastDomain, run: Timestamp) throws {
        /// download seamask and height
        if FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm) {
            return
        }
        
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        logger.info("Downloading height and elevation data")
        let url = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.\(run.format_YYYYMMdd)/\(run.hour.zeroPadded(len: 2))/6hrly_grib_01/flxf\(run.format_YYYYMMddHH).01.\(run.format_YYYYMMddHH).grb2"
        
        enum ElevationVariable: String, CurlIndexedVariable, CaseIterable {
            case height
            case landmask
            
            var gribIndexName: String {
                switch self {
                case .height:
                    return ":HGT:surface:"
                case .landmask:
                    return ":LAND:surface:"
                }
            }
        }
        
        var height: Array2D? = nil
        var landmask: Array2D? = nil
        let curl = Curl(logger: logger)
        for (variable, data2) in try curl.downloadIndexedGrib(url: url, variables: ElevationVariable.allCases) {
            var data = data2
            data.shift180LongitudeAndFlipLatitude()
            switch variable {
            case .height:
                height = data
            case .landmask:
                landmask = data
            }
            //try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.rawValue).nc")
        }
        guard var height = height, let landmask = landmask else {
            fatalError("Could not download land and sea mask")
        }
        for i in height.data.indices {
            // landmask: 0=sea, 1=land
            height.data[i] = landmask.data[i] == 1 ? height.data[i] : -999
        }
        try OmFileWriter.write(file: domain.surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20, all: height.data)
    }*/
    
    func downloadGfs(logger: Logger, domain: NcepDomain, run: Timestamp, variables: [GfsVariable], skipFilesIfExisting: Bool) throws {
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        
        let curl = Curl(logger: logger)
        let forecastHours = domain.forecastHours
        let variablesHour0 = variables.filter({!$0.skipHour0})
        
        for forecastHour in forecastHours {
            logger.info("Downloading forecastHour \(forecastHour)")
            let variables = (forecastHour == 0 ? variablesHour0 : variables).filter { variable in
                let fileDest = "\(domain.downloadDirectory)\(variable.rawValue)_\(forecastHour).fpg"
                return !skipFilesIfExisting || !FileManager.default.fileExists(atPath: fileDest)
            }
            if variables.isEmpty {
                continue
            }
            
            //https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.20220813/00/atmos/gfs.t00z.pgrb2.0p25.f084.idx
            let url = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.\(run.format_YYYYMMdd)/\(run.hh)/atmos/gfs.t\(run.hh)z.pgrb2.0p25.f\(forecastHour.zeroPadded(len: 3))"
            
            for (variable, data) in try curl.downloadIndexedGrib(url: url, variables: variables) {
                var data = data
                data.shift180LongitudeAndFlipLatitude()
                //try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.rawValue)_\(forecastHour).nc")
                try FloatArrayCompressor.write(file: "\(domain.downloadDirectory)\(variable.rawValue)_\(forecastHour).fpg", data: data.data)
            }
        }
    }
    
    /// Process each variable and update time-series optimised files
    func convertGfs(logger: Logger, domain: NcepDomain, variables: [GfsVariable], run: Timestamp) throws {
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        let forecastHours = domain.forecastHours
        let nForecastHours = forecastHours.max()!+1
        
        let grid = domain.grid
        let nLocation = grid.count
        
        
        for variable in variables {
            let startConvert = DispatchTime.now()
            logger.info("Converting \(variable)")
            
            var data2d = Array2DFastTime(nLocations: nLocation, nTime: nForecastHours)

            for forecastHour in forecastHours {
                if forecastHour == 0 && variable.skipHour0 {
                    continue
                }
                let file = "\(domain.downloadDirectory)\(variable.rawValue)_\(forecastHour).fpg"
                data2d[0..<nLocation, forecastHour] = try FloatArrayCompressor.read(file: file, nElements: nLocation)
            }
            
            let skip = variable.skipHour0 ? 1 : 0
            
            // Deaverage radiation. Not really correct for 3h data after 120 hours.
            if variable.isAveragedOverForecastTime {
                data2d.deavergeOverTime(slidingWidth: 6, slidingOffset: skip)
            }
            
            // interpolate missing timesteps. We always fill 2 timesteps at once
            // data looks like: DDDDDDDDDD--D--D--D--D--D
            let forecastStepsToInterpolate = (0..<nForecastHours).compactMap { hour -> Int? in
                if forecastHours.contains(hour) || hour % 3 != 1 {
                    // process 2 timesteps at once
                    return nil
                }
                return hour
            }
            
            switch variable.interpolationType {
            case .linear:
                data2d.interpolate2StepsLinear(positions: forecastStepsToInterpolate)
            case .nearest:
                data2d.interpolate2StepsNearest(positions: forecastStepsToInterpolate)
            case .solar_backwards_averaged:
                data2d.interpolate2StepsSolarBackwards(positions: forecastStepsToInterpolate, grid: domain.grid, run: run, dtSeconds: domain.dtSeconds)
            case .hermite:
                data2d.interpolate2StepsHermite(positions: forecastStepsToInterpolate)
            case .hermite_backwards_averaged:
                data2d.interpolate2StepsHermiteBackwardsAveraged(positions: forecastStepsToInterpolate)
            }
            
            if let fma = variable.multiplyAdd {
                data2d.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
            }
            
            // De-accumulate precipitation
            if variable.isAccumulatedSinceModelStart {
                data2d.deaccumulateOverTime(slidingWidth: data2d.nTime, slidingOffset: skip)
            }
            
            let ringtime = run.timeIntervalSince1970 / 3600 ..< run.timeIntervalSince1970 / 3600 + nForecastHours
            
            
            //try data2d.transpose().writeNetcdf(filename: "\(domain.downloadDirectory)\(variable).nc", nx: grid.nx, ny: grid.ny)
            
            logger.info("Reading and interpolation done in \(startConvert.timeElapsedPretty()). Starting om file update")
            let startOm = DispatchTime.now()
            try om.updateFromTimeOriented(variable: variable.omFileName, array2d: data2d, ringtime: ringtime, skipFirst: skip, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor)
            logger.info("Update om finished in \(startOm.timeElapsedPretty())")
        }
    }
}