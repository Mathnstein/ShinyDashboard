library(shiny)
library(shinydashboard)
library(leaflet)
library(ggplot2)
library(dplyr)
library(readxl)
library(rgdal)
library(data.table)
library(tmap)
library(tmaptools)

server <- function(input, output, session) {
	# Import data
	shape <- readOGR(dsn="./data/nh_noshore_29Jan13.shp",
									 layer="nh_noshore_29Jan13", GDAL1_integer64_policy='TRUE')
	# Skip the weird notes at the top of excel file, skip = 6
	edi <- read_excel("./data/edi_wave2-6.xlsx",
											sheet = 2,col_names = TRUE,skip=6)
	# Create temporary data table to work on only Surrey, then maps coordinates back to Lat Long
	shape.surrey <- shape[shape$SD_NAME == "Surrey",]
	shape.surrey <- spTransform(shape.surrey, CRS("+init=epsg:4326"))
	surrey.data <- data.frame(shape.surrey@data)
	surrey.data$N_CODE <- sapply(surrey.data$N_CODE,as.character)
	edi.surrey <- filter(edi,N_CODE %in% surrey.data$N_CODE) 
	edi.surrey <- subset(edi.surrey, select = -c(n_code_name))
	shape.surrey <- append_data(shp = shape.surrey, data = edi.surrey, 
															key.shp = "N_CODE", key.data = "N_CODE")
	

	# Begin Plots	
	output$SHPplot <- renderLeaflet({
		wave <- switch(input$radio,
									 "Wave 2: 2004-2007" = shape.surrey$editot_2,
									 "Wave 3: 2007-2009" = shape.surrey$editot_3,
									 "Wave 4: 2009-2011" = shape.surrey$editot_4,
									 "Wave 5: 2011-2013" = shape.surrey$editot_5,
									 "Wave 6: 2013-2016" = shape.surrey$editot_6)
		isolate({
		# Color based on edi
		qpal <- colorBin(rev(heat.colors(5)), wave, bins=5)	
		# Plot shapes
		shape.Plot <- leaflet(shape.surrey) %>% 
			addPolygons(stroke = TRUE,opacity = 1,fillOpacity = 0.5, smoothFactor = 0.5,
									color="black",fillColor = ~qpal(wave),weight = 1,popup = shape.surrey$N_NAME,
									highlight = highlightOptions(weight = 5, color = "#666",fillOpacity = 0.7,
																							 bringToFront = TRUE)) %>%
			addLegend(values=~wave,pal=qpal,title="Vulnerable count")
		shape.Plot %>% addTiles()
		})
	})
	
	updateSelectizeInput(session, 'neighborhood', choices = surrey.data$N_NAME, server = TRUE)
	
	output$edi_overall <- renderPlot({
		if(input$neighborhood == ""){
			print(input$neighborhood)
			dat <- shape.surrey@data[,grep("editot", names(shape.surrey@data))]
			dat <- round(colMeans(dat))
			waves <- 2:6
			df <- data.frame(wave = waves, edi_scores = dat)
			ggplot(data=df, aes(x=wave, y=edi_scores)) +
				geom_line()+
				geom_point()+
				xlab("Wave")+
				ylab("Number of children vulnerable")+
				ggtitle("EDI vulnerability for each wave")
		} else if (!is.null(input$neighborhood)){
			print(input$neighborhood)
			dat <- filter(shape.surrey@data, N_NAME == input$neighborhood)
			dat <- dat[,grep("editot", names(dat))]
			dat <- colMeans(dat)
			waves <- 2:6
			df <- data.frame(wave = waves, edi_scores = dat)
			ggplot(data=df, aes(x=wave, y=edi_scores)) +
				geom_line()+
				geom_point()+
				xlab("Wave")+
				ylab("Number of children vulnerable")+
				ggtitle("EDI vulnerability for each wave")
		}
	})
	output$edi_physical <- renderPlot({
		if(input$neighborhood == ""){
			print(input$neighborhood)
			dat <- shape.surrey@data[,grep("PCTPHYRI", names(shape.surrey@data))]
			dat <- round(colMeans(dat))
			waves <- 2:6
			df <- data.frame(wave = waves, edi_scores = dat)
			ggplot(data=df, aes(x=wave, y=edi_scores)) +
				geom_line()+
				geom_point()+
				xlab("Wave")+
				ylab("Percent vulnerable (%)")+
				ggtitle("Physical Vulnerability")+
				theme_classic()
		} else if (!is.null(input$neighborhood)){
			print(input$neighborhood)
			dat <- filter(shape.surrey@data, N_NAME == input$neighborhood)
			dat <- dat[,grep("PCTPHYRI", names(dat))]
			dat <- colMeans(dat)
			waves <- 2:6
			df <- data.frame(wave = waves, edi_scores = dat)
			ggplot(data=df, aes(x=wave, y=edi_scores)) +
				geom_line()+
				geom_point()+
				xlab("Wave")+
				ylab("Percent vulnerable")+
				ggtitle("Physical Vulnerability (%)")+
				theme_classic()
		}
	})
}
