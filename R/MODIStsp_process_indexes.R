#'  MODIStsp_process_indexes
#' @description function used to compute spectral indexes, given the index formula
#' @details the function parses the index formula to identify the required bands. On the basis
#' of identified bands, it retrieves the reflectance bands required, gets the data into R raster
#' objects, performs the computation and stores results in a GeoTiff or ENVI raster file
#' @param out_filename basename of the file in to which save results
#' @param formula string Index formula, as derived from XML file and stored in prod_opts 
#' within previous_file
#' @param bandnames string array of names of original HDF layer. Used to identify the 
#' bands required for index computation
#' @param nodata_out string array of nodata values of reflectance bands
#' @param indexes_nodata_out string nodata value for resulting raster
#' @param out_prod_folder strng output folder for the product used to retrieve filenames 
#' of rasters of original bands to be used in computations
#' @param file_prefix string used to retrieve filenames of rasters of original bands 
#' to be used in computations
#' @param yy string string used to retrieve filenames of rasters of original bands 
#' to be used in computations
#' @param DOY string used to retrieve filenames of rasters of original bands to be 
#' used in computations
#' @param out_format string used to retrieve filenames of rasters of original bands 
#' to be used in computations
#' @param scale_val string (Yes/No) if Yes, output values in are computed as float -1 - 1, 
#' otherwise integer -10000 - 10000
#' @return NULL - new raster file saved in out_filename
#'
#' @author Lorenzo Busetto, phD (2014-2015) \email{busetto.l@@irea.cnr.it}
#' @author Luigi Ranghetti, phD (2015) \email{ranghetti.l@@irea.cnr.it}
#' @note License: GPL 3.0
#' @importFrom raster NAvalue raster writeRaster
#' @importFrom tools file_path_sans_ext
MODIStsp_process_indexes <- function(out_filename, formula, bandnames,
                                     nodata_out, out_prod_folder,
                                     indexes_nodata_out, file_prefix, 
                                     yy, DOY, out_format, scale_val) {

  # Retrieve necessary filenames (get names of single band files on the basis of Index formula)

  call_string <- "tmp_index <- index("   # initialize the "call string " for the computation
  fun_string <- "index <- function("		 # initialize the "fun_string" --> in the end, fun_string contains a complete function definition
  # Parsing it allows to create on the fly a function to compute the specific index required
  # search in bandnames the original bands required for the index
  for (band in seq(along = bandnames)) {
    bandsel <- bandnames[band]
    # look if the bandname is present in the formula. If so, retrieve the filename for that band
    # and store its data in a R object that takes its name from the band name
    if (length(grep(bandsel, formula)) > 0) {
      temp_bandname <- bandnames[grep(bandsel, bandnames)]
      # file name for the band, year, doy
      temp_file <- file.path(out_prod_folder, temp_bandname, 
                             paste0(file_prefix, "_", temp_bandname, "_", yy, "_", DOY))
      if (out_format == "GTiff")  {
        temp_file <- paste0(temp_file, ".tif")
      }
      if (out_format == "ENVI") {
        temp_file <- paste0(temp_file, ".dat")
      }
      temp_raster <- raster(temp_file)   # put data in a raster object
      raster::NAvalue(temp_raster) <- as.numeric(nodata_out[band])  # assign NA value
      assign(temp_bandname, temp_raster) # assign the data to a object with name = bandname
      # add an "entry" in call_string (additional parameter to be passed to function
      call_string <- paste0(call_string, temp_bandname, "=", temp_bandname, "," )
      # add an "entry" in fun_string (additional input parameter)
      fun_string  <- paste0(fun_string, temp_bandname, "=", temp_bandname, "," )  
    }
  }
  call_string <- paste0(substr(call_string, 1, nchar(call_string) - 1), ")")  #Finalize the call_string
  if (scale_val == "Yes") {
    # if scale_val, indices are written as float -1 - 1
    fun_string <- paste0(fun_string, "...)", "{", formula, "}") # Finalize the fun_string
  } else {
    # otherwise, they are written as integer -10000 - 10000
    fun_string <- paste0(fun_string, "...)", "{round(10000*(", formula, "))}") # Finalize the fun_string
  }
  
  eval(parse(text = fun_string))     # Parse "fun_string" to create a new function
  eval(parse(text = call_string))    # parse call_string to launch the new function for index computation

  # Save output and remove aux file
  raster::NAvalue(tmp_index) <- as.numeric(indexes_nodata_out)
  writeRaster(tmp_index, out_filename, format = out_format, NAflag = as.numeric(indexes_nodata_out), 
              datatype = if (scale_val == "Yes"){"FLT4S"} else {"INT2S"}, overwrite = TRUE)
  # IF "ENVI", write the nodata value in the header
  if (out_format == "ENVI") { 
    # If output format is ENVI, add data ignore value to the header file
    fileConn_meta_hdr <- file(paste0(tools::file_path_sans_ext(out_filename), ".hdr"), "a")  
    # Data Ignore Value
    writeLines(c("data ignore value = ", indexes_nodata_out ), fileConn_meta_hdr, sep = " ")		
    writeLines("", fileConn_meta_hdr)
    close(fileConn_meta_hdr)
  }
  # Delete xml files created by writeRaster
  xml_file <- paste0(out_filename, ".aux.xml")		
  unlink(xml_file)

  gc()

}
