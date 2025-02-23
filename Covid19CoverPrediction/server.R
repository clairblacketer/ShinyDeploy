# @file server.R
#
# Copyright 2018 Observational Health Data Sciences and Informatics
#
# This file is part of PatientLevelPrediction
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

library(shiny)
library(plotly)
library(shinycssloaders)

source("helpers.R")
source("plots.R")

server <- shiny::shinyServer(function(input, output, session) {
  session$onSessionEnded(shiny::stopApp)
  filterIndex <- shiny::reactive({getFilter(summaryTable,input)})
  
  print(summaryTable)
  ###Risk Calculator
  inputData  <- shiny::reactiveValues(dataHosp = NULL, dataIntense = NULL, dataDeath = NULL)
  riskValues  <- shiny::reactiveValues(data = NULL)
  # initial language setting
  i18n <- Translator$new(translation_csvs_path = "./www/languages/translation/")
  i18n$set_translation_language("en")
  
  shiny::observeEvent(input$calculate, {
    inputData$dataHosp <- data.frame(
      Intercept = 43, #updated to make scale positive
      age = ageCalc(input$age, 'Hospitalization'),
      sex = ifelse(input$sex == "Male",3,0),
      cancer = input$cancer * 2,
      copd = input$copd * 6,
      diabetes = input$diabetes * 3,
      'heart disease' = input$hd * 4,
      hyperlipidemia = input$hl * -3,
      hypertension = input$hypertension * 3,
      kidney = input$kidney * 2
    )
    
    inputData$dataIntense  <- data.frame(
      Intercept = 27, #updated to make scale positive
      age = ageCalc(input$age, 'Intensive Care'),
      sex = ifelse(input$sex == "Male",4,0),
      cancer = input$cancer * 1,
      copd = input$copd * 6,
      diabetes = input$diabetes * 4,
      'heart disease' = input$hd * 4,
      hyperlipidemia = input$hl * -4,
      hypertension = input$hypertension * 5,
      kidney = input$kidney * 4
    )
    
    inputData$dataDeath <- data.frame(
      Intercept = 27, #updated to make scale positive
      age = ageCalc(input$age, 'Death'),
      sex = ifelse(input$sex == "Male",4,0),
      cancer = input$cancer * 3,
      copd = input$copd * 4,
      diabetes = input$diabetes * 2,
      'heart disease' = input$hd * 2,
      hyperlipidemia = input$hl * -7,
      hypertension = input$hypertension * 3,
      kidney = input$kidney * 2
    )
    totals <- unlist(lapply(inputData,  function(x){rowSums(x) - 93})) #subtract the 93 we used to make positive
    #TODO: update to match names in paper
    riskValues$data <- data.frame(names = c('COVER-H','COVER-I', 'COVER-F'),
                                  values = 1/(1+exp(-totals/10)) *100, stringsAsFactors = F)
    
    
    
    #sort by values (descending) probably a better way to do this...
    riskValues$data$names <- factor(riskValues$data$names,
                                    levels = unique(riskValues$data$names)[order(riskValues$data$values,
                                                                                 decreasing = FALSE)])
    #moved this here because there is a warning if done in plotting
    riskValues$data$values <- round(riskValues$data$values, 1)
    riskValues$data$values[riskValues$data$values ==0] <- 0.1
    riskValues$data$color <- cut(riskValues$data$values,
                                 breaks = c(0,10, 15, 100),
                                 labels = c("#D6BA84", "#D35836","#981B1E" ))
    # Red #981B1E , Orange #D35836 and Golden #D6BA84
  })
  observeEvent(input$language, {
    i18n$set_translation_language(input$language)
    output$risktabside <- shiny::renderUI(
      sidebarPanel(
        shiny::p(i18n$t('Use this tool to calculate the risk of COVID outcomes: ')),
        shiny::p(' '),
        shiny::sliderInput("age", i18n$t("Age:"),
                           min = 18, max = 94,
                           value = 50),
        shiny::selectInput("sex",i18n$t("Sex"), choices = c(i18n$t("Male"), i18n$t("Female"))),
        shiny::checkboxInput("cancer", i18n$t("History of Cancer")),
        shiny::checkboxInput("copd", i18n$t("History of COPD")),
        shiny::checkboxInput("diabetes", i18n$t("History of Diabetes")),
        shiny::checkboxInput("hd", i18n$t("History of Heart disease")),
        shiny::checkboxInput("hl", i18n$t("History of Hyperlipidemia")),
        shiny::checkboxInput("hypertension", i18n$t("History of Hypertension")),
        shiny::checkboxInput("kidney",i18n$t("History of Kidney Disease")),
        shiny::actionButton("calculate",i18n$t("Calculate Risk")),
        hr()
        
      ))
    
    output$risktabmain <- shiny::renderUI(
      mainPanel(
        conditionalPanel('input.calculate', {
          shinydashboard::box(width = 12,
                              title = tagList(shiny::icon("bar-chart"),i18n$t("Predicted Risk (%)")), status = "info", solidHeader = TRUE,
                              
                              plotly::plotlyOutput("contributions"))}
          
        ),
        shinydashboard::box(
          status = "primary", solidHeader = TRUE,
          width = 12,
          shiny::includeMarkdown(path = paste0("./www/languages/calculatorDesc_", input$language, ".md"))
          #   shiny::h2("Description"),
          #   # shiny::p("The Observational Health Data Sciences and Informatics (OHDSI) international community is hosting a COVID-19 virtual study-a-thon this week (March 26-29) to inform healthcare decision-making in response to the current global pandemic."),
          #   shiny::p("This calculator presents the results of a prediction study that developed 3 prediction models."),
          #   shiny::p("The three models predicted: requiring hospital admission (COVER-H), requiring intensive services (COVER-I), or fatality (COVER-F) in the month following COVID-19 diagnosis"),
          #   shiny::p(' '),
          #   shiny::h3("Disclaimer"),
          #   shiny::p('Should not be considered Medical Advice.
          #                                                                    By using the app, you acknowledge that the content does not constitute medical advice and does not create a Healthcare Professional - Patient relationship and does not constitute medical opinion or advice.
          #                                                                    Access to general information is provided for research and educational purposes only.
          #                                                                    Content is not recommended or endorsed by any doctor or healthcare provider.
          #                                                                    The information provided is not a substitute for medical or professional care,
          #                                                                    and you should not use the information in place of an appointment or the advice of your physician or other healthcare provider.
          #                                                                    You are liable or responsible for any action taken through use of information in this site.'), #Todo: add disclaimer
        ),                                                                  )
    )
  })
  #plot for the risk score calculator
  output$contributions <- plotly::renderPlotly(plotly::plot_ly(x = as.double(riskValues$data$values), 
                                                               y = riskValues$data$names, 
                                                               text = paste0(riskValues$data$values,'%'), textposition = 'auto', insidetextfont = list(size=20, color = 'white'),
                                                               color = riskValues$data$color,
                                                               colors = levels(riskValues$data$color),
                                                               type = 'bar', orientation = 'h', showlegend = F) %>% layout(
                                                                 xaxis = list(
                                                                   range=c(-0.1,max(riskValues$data$values)*1.25)
                                                                 )
                                                               ))
  # need to remove over columns:
  output$summaryTable <- DT::renderDataTable(DT::datatable(summaryTable[filterIndex(),!colnames(summaryTable)%in%c('addExposureDaysToStart','addExposureDaysToEnd', 'plpResultLocation', 'plpResultLoad')],
                                                           rownames= FALSE, selection = 'single'))
  
  selectedRow <- shiny::reactive({
    if(is.null(input$summaryTable_rows_selected[1])){
      return(1)
    }else{
      return(input$summaryTable_rows_selected[1])
    }
  })
  
  
  
  plpResult <- shiny::reactive({getPlpResult(result,validation,summaryTable, inputType,filterIndex(), selectedRow())})
  
  # covariate table
  output$modelView <- DT::renderDataTable(editCovariates(plpResult()$covariateSummary)$table,  
                                          colnames = editCovariates(plpResult()$covariateSummary)$colnames)
  
  
  output$modelCovariateInfo <- DT::renderDataTable(data.frame(covariates = nrow(plpResult()$covariateSummary),
                                                              nonZeroCount = sum(plpResult()$covariateSummary$covariateValue!=0)))
  
  # Downloadable csv of model ----
  output$downloadData <- shiny::downloadHandler(
    filename = function(){'model.csv'},
    content = function(file) {
      write.csv(plpResult()$covariateSummary[plpResult()$covariateSummary$covariateValue!=0,c('covariateName','covariateValue','CovariateCount','CovariateMeanWithOutcome','CovariateMeanWithNoOutcome' )]
                , file, row.names = FALSE)
    }
  )
  
  # input tables
  output$modelTable <- DT::renderDataTable(formatModSettings(plpResult()$model$modelSettings  ))
  output$covariateTable <- DT::renderDataTable(formatCovSettings(plpResult()$model$metaData$call$covariateSettings))
  output$populationTable <- DT::renderDataTable(formatPopSettings(plpResult()$model$populationSettings))
  
  
  
  
  # prediction text
  output$info <- shiny::renderText(paste0('Within ', summaryTable[filterIndex(),'T'][selectedRow()],
                                          ' predict who will develop ',  summaryTable[filterIndex(),'O'][selectedRow()],
                                          ' during ',summaryTable[filterIndex(),'TAR start'][selectedRow()], ' day/s',
                                          ' after ', ifelse(summaryTable[filterIndex(),'addExposureDaysToStart'][selectedRow()]==0, ' cohort start ', ' cohort end '),
                                          ' and ', summaryTable[filterIndex(),'TAR end'][selectedRow()], ' day/s',
                                          ' after ', ifelse(summaryTable[filterIndex(),'addExposureDaysToEnd'][selectedRow()]==0, ' cohort start ', ' cohort end '))
  )
  
  # PLOTTING FUNCTION
  plotters <- shiny::reactive({
    
    eval <- plpResult()$performanceEvaluation
    if(is.null(eval)){return(NULL)}
    
    calPlot <- NULL 
    rocPlot <- NULL
    prPlot <- NULL
    f1Plot <- NULL
    
    if(!is.null(eval)){
      #intPlot <- plotShiny(eval, input$slider1) -- RMS
      intPlot <- plotShiny(eval)
      rocPlot <- intPlot$roc
      prPlot <- intPlot$pr
      f1Plot <- intPlot$f1score
      
      list(rocPlot= rocPlot,
           prPlot=prPlot, f1Plot=f1Plot)
    }
  })
  
  
  performance <- shiny::reactive({
    
    eval <- plpResult()$performanceEvaluation
    
    if(is.null(eval)){
      return(NULL)
    } else {
      intPlot <- getORC(eval, input$slider1)
      threshold <- intPlot$threshold
      prefthreshold <- intPlot$prefthreshold
      TP <- intPlot$TP
      FP <- intPlot$FP
      TN <- intPlot$TN
      FN <- intPlot$FN
    }
    
    twobytwo <- as.data.frame(matrix(c(FP,TP,TN,FN), byrow=T, ncol=2))
    colnames(twobytwo) <- c('Ground Truth Negative','Ground Truth Positive')
    rownames(twobytwo) <- c('Predicted Positive','Predicted Negative')
    
    list(threshold = threshold, 
         prefthreshold = prefthreshold,
         twobytwo = twobytwo,
         Incidence = (TP+FN)/(TP+TN+FP+FN),
         Threshold = threshold,
         Sensitivity = TP/(TP+FN),
         Specificity = TN/(TN+FP),
         PPV = TP/(TP+FP),
         NPV = TN/(TN+FN) )
  })
  
  
  # preference plot
  output$prefdist <- shiny::renderPlot({
    if(is.null(plpResult()$performanceEvaluation)){
      return(NULL)
    } else{
      plotPreferencePDF(plpResult()$performanceEvaluation, 
                        type=plpResult()$type ) #+ 
      # ggplot2::geom_vline(xintercept=plotters()$prefthreshold) -- RMS
    }
  })
  
  output$preddist <- shiny::renderPlot({
    if(is.null(plpResult()$performanceEvaluation)){
      return(NULL)
    } else{
      plotPredictedPDF(plpResult()$performanceEvaluation, 
                       type=plpResult()$type ) # + 
      #ggplot2::geom_vline(xintercept=plotters()$threshold) -- RMS     
    }
  })
  
  output$box <- shiny::renderPlot({
    if(is.null(plpResult()$performanceEvaluation)){
      return(NULL)
    } else{
      plotPredictionDistribution(plpResult()$performanceEvaluation, type=plpResult()$type )
    }
  })
  
  output$cal <- shiny::renderPlot({
    if(is.null(plpResult()$performanceEvaluation)){
      return(NULL)
    } else{
      plotSparseCalibration2(plpResult()$performanceEvaluation, type=plpResult()$type )
    }
  })
  
  output$demo <- shiny::renderPlot({
    if(is.null(plpResult()$performanceEvaluation)){
      return(NULL)
    } else{
      tryCatch(plotDemographicSummary(plpResult()$performanceEvaluation, 
                                      type=plpResult()$type ),
               error= function(cond){return(NULL)})
    }
  })
  
  
  
  # Do the tables and plots:
  
  output$performance <- shiny::renderTable(performance()$performance, 
                                           rownames = F, digits = 3)
  output$twobytwo <- shiny::renderTable(performance()$twobytwo, 
                                        rownames = T, digits = 0)
  
  
  output$threshold <- shiny::renderText(format(performance()$threshold,digits=5))
  
  output$roc <- plotly::renderPlotly({
    plotters()$rocPlot
  })
  
  output$pr <- plotly::renderPlotly({
    plotters()$prPlot
  })
  output$f1 <- plotly::renderPlotly({
    plotters()$f1Plot
  })
  
  
  
  
  
  
  # covariate model plots
  covs <- shiny::reactive({
    if(is.null(plpResult()$covariateSummary))
      return(NULL)
    plotCovariateSummary(formatCovariateTable(plpResult()$covariateSummary))
  })
  
  output$covariateSummaryBinary <- plotly::renderPlotly({ covs()$binary })
  output$covariateSummaryMeasure <- plotly::renderPlotly({ covs()$meas })
  
  # LOG
  output$log <- shiny::renderText( paste(plpResult()$log, collapse="\n") )
  
  # dashboard
  
  output$performanceBoxIncidence <- shinydashboard::renderInfoBox({
    shinydashboard::infoBox(
      "Incidence", paste0(round(performance()$Incidence*100, digits=3),'%'), icon = shiny::icon("ambulance"),
      color = "green"
    )
  })
  
  output$performanceBoxThreshold <- shinydashboard::renderInfoBox({
    shinydashboard::infoBox(
      "Threshold", format((performance()$Threshold), scientific = F, digits=3), icon = shiny::icon("edit"),
      color = "yellow"
    )
  })
  
  output$performanceBoxPPV <- shinydashboard::renderInfoBox({
    shinydashboard::infoBox(
      "PPV", paste0(round(performance()$PPV*1000)/10, "%"), icon = shiny::icon("thumbs-up"),
      color = "orange"
    )
  })
  
  output$performanceBoxSpecificity <- shinydashboard::renderInfoBox({
    shinydashboard::infoBox(
      "Specificity", paste0(round(performance()$Specificity*1000)/10, "%"), icon = shiny::icon("bullseye"),
      color = "purple"
    )
  })
  
  output$performanceBoxSensitivity <- shinydashboard::renderInfoBox({
    shinydashboard::infoBox(
      "Sensitivity", paste0(round(performance()$Sensitivity*1000)/10, "%"), icon = shiny::icon("low-vision"),
      color = "blue"
    )
  })
  
  output$performanceBoxNPV <- shinydashboard::renderInfoBox({
    shinydashboard::infoBox(
      "NPV", paste0(round(performance()$NPV*1000)/10, "%"), icon = shiny::icon("minus-square"),
      color = "black"
    )
  })
  
})