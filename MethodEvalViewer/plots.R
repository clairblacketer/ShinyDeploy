library(ggplot2)

plotScatter <- function(d) {
  d$Significant <- d$ci95Lb > d$targetEffectSize | d$ci95Ub < d$targetEffectSize
  
  temp1 <- aggregate(Significant ~ Group, data = d, length)
  temp2 <- aggregate(Significant ~ Group, data = d, mean)
  
  temp1$nLabel <- paste0(formatC(temp1$Significant, big.mark = ","), " estimates")
  temp1$Significant <- NULL
  
  temp2$meanLabel <- paste0(formatC(100 * (1 - temp2$Significant), digits = 1, format = "f"),
                            "% of CIs includes ",
                            substr(as.character(temp2$Group), start = 21, stop = nchar(as.character(temp2$Group))))
  temp2$Significant <- NULL
  dd <- merge(temp1, temp2)
  # print(substr(as.character(dd$Group), start = 20, stop = nchar(as.character(dd$Group))))
  dd$tes <- as.numeric(substr(as.character(dd$Group), start = 21, stop = nchar(as.character(dd$Group))))
  
  breaks <- c(0.25, 0.5, 1, 2, 4, 6, 8, 10)
  theme <- element_text(colour = "#000000", size = 14)
  themeRA <- element_text(colour = "#000000", size = 14, hjust = 1)
  themeLA <- element_text(colour = "#000000", size = 14, hjust = 0)
  alpha <- 1 - min(0.95*(nrow(d)/nrow(dd)/50000)^0.1, 0.95)
  plot <- ggplot(d, aes(x = logRr, y= seLogRr), environment = environment()) +
    geom_vline(xintercept = log(breaks), colour = "#CCCCCC", lty = 1, size = 0.5) +
    geom_abline(aes(intercept = (-log(tes))/qnorm(0.025), slope = 1/qnorm(0.025)), colour = rgb(0.8, 0, 0), linetype = "dashed", size = 1, alpha = 0.5, data = dd) +
    geom_abline(aes(intercept = (-log(tes))/qnorm(0.975), slope = 1/qnorm(0.975)), colour = rgb(0.8, 0, 0), linetype = "dashed", size = 1, alpha = 0.5, data = dd) +
    geom_point(size = 2, color = rgb(0, 0, 0, alpha = 0.05), alpha = alpha, shape = 16) +
    geom_hline(yintercept = 0) +
    geom_label(x = log(0.26), y = 0.95, alpha = 1, hjust = "left", aes(label = nLabel), size = 5, data = dd) +
    geom_label(x = log(0.26), y = 0.8, alpha = 1, hjust = "left", aes(label = meanLabel), size = 5, data = dd) +
    scale_x_continuous("Estimated effect size", limits = log(c(0.25, 10)), breaks = log(breaks), labels = breaks) +
    scale_y_continuous("Standard Error", limits = c(0, 1)) +
    facet_grid(. ~ Group) +
    theme(panel.grid.minor = element_blank(),
          panel.background = element_blank(),
          panel.grid.major = element_blank(),
          axis.ticks = element_blank(),
          axis.text.y = themeRA,
          axis.text.x = theme,
          axis.title = theme,
          legend.key = element_blank(),
          strip.text.x = theme,
          strip.text.y = theme,
          strip.background = element_blank(),
          legend.position = "none")
  return(plot)
}

plotRocsInjectedSignals <- function(logRr, trueLogRr, showAucs, fileName = NULL) {
  trueLogRrLevels <- unique(trueLogRr)
  trueLogRrLevels <- trueLogRrLevels[order(trueLogRrLevels)]
  allData <- data.frame()
  aucs <- c()
  labels <- c()
  overall <- c()
  for (trueLogRrLevel in trueLogRrLevels) {
    if (trueLogRrLevel != 0 ) {
      data <- data.frame(logRr = logRr[trueLogRr == 0 | trueLogRr == trueLogRrLevel], 
                         trueLogRr = trueLogRr[trueLogRr == 0 | trueLogRr == trueLogRrLevel])
      data$truth <- data$trueLogRr != 0
      label <- paste("True effect size =", exp(trueLogRrLevel))
      roc <- pROC::roc(data$truth, data$logRr, algorithm = 3)
      if (showAucs) {
        aucs <- c(aucs, pROC::auc(roc))
        labels <- c(labels, label)
        overall <- c(overall, FALSE)
      }
      data <- data.frame(sens = roc$sensitivities, 
                         fpRate = 1 - roc$specificities, 
                         label = label,
                         overall = FALSE,
                         stringsAsFactors = FALSE)
      data <- data[order(data$sens, data$fpRate), ]
      allData <- rbind(allData, data)
    }
  }
  # Overall ROC
  data <- data.frame(logRr = logRr, 
                     trueLogRr = trueLogRr)
  data$truth <- data$trueLogRr != 0
  roc <- pROC::roc(data$truth, data$logRr, algorithm = 3)
  if (showAucs) {
    aucs <- c(aucs, pROC::auc(roc))
    labels <- c(labels, "Overall")
    overall <- c(overall, TRUE)
  }
  data <- data.frame(sens = roc$sensitivities, 
                     fpRate = 1 - roc$specificities, 
                     label = "Overall", 
                     overall = TRUE,
                     stringsAsFactors = FALSE)
  data <- data[order(data$sens, data$fpRate), ]
  allData <- rbind(allData, data)
  
  allData$label <- factor(allData$label, levels = c(paste("True effect size =", exp(trueLogRrLevels)), "Overall"))
  # labels <- factor(labels, levels = c("Overall", paste("True effect size =", exp(trueLogRrLevels))))
  breaks <- seq(0, 1, by = 0.2)
  theme <- element_text(colour = "#000000", size = 15)
  themeRA <- element_text(colour = "#000000", size = 15, hjust = 1)
  plot <- ggplot(allData, aes(x = fpRate, y = sens, group = label, color = label, fill = label)) +
    geom_vline(xintercept = breaks, colour = "#CCCCCC", lty = 1, size = 0.5) +
    geom_hline(yintercept = breaks, colour = "#CCCCCC", lty = 1, size = 0.5) +
    geom_abline(intercept = 0, slope = 1) +
    geom_line(aes(linetype = overall), alpha = 0.5, size = 1) +
    scale_x_continuous("1 - specificity", breaks = breaks, labels = breaks) +
    scale_y_continuous("Sensitivity", breaks = breaks, labels = breaks) +
    labs(color = "True effect size", linetype = "Overall") +
    theme(panel.grid.minor = element_blank(),
          panel.background = element_blank(),
          panel.grid.major = element_blank(),
          axis.ticks = element_blank(),
          axis.text.y = themeRA,
          axis.text.x = theme,
          axis.title = theme,
          legend.key = element_blank(),
          strip.text.x = theme,
          strip.text.y = theme,
          strip.background = element_blank(),
          legend.position = "right",
          legend.text = theme,
          legend.title = theme)
  
  
  if (showAucs) {
    aucs <- data.frame(auc = aucs, label = labels) 
    aucs <- aucs[order(aucs$label, decreasing = TRUE), ]
    for (i in 1:nrow(aucs)) {
      label <- paste0(aucs$label[i], ": AUC = ", format(round(aucs$auc[i], 2), nsmall = 2))
      plot <- plot + geom_text(label = label, x = 1, y = 0.4 - (i*0.1), hjust = 1, color = "#000000", size = 5)
    }
  }
  if (!is.null(fileName))
    ggsave(fileName, plot, width = 5.5, height = 4.5, dpi = 400)
  return(plot)
}

plotOverview <- function(metrics, metric, strataSubset, calibrated) {
  yLabel <- paste0(metric, if (calibrated == "Calibrated") " after empirical calibration" else "")
  point <- scales::format_format(big.mark = " ", decimal.mark = ".", scientific = FALSE)
  fiveColors <- c(
    "#781C86",
    "#83BA70",
    "#D3AE4E",
    "#547BD3",
    "#DF4327"
  )
  plot <- ggplot2::ggplot(metrics, ggplot2::aes(x = x, y = metric, color = tidyMethod)) +
    ggplot2::geom_vline(xintercept = 0.5 + 0:nrow(strataSubset), linetype = "dashed") +
    ggplot2::geom_point(size = 4.5, alpha = 0.5, shape = 16) +
    ggplot2::scale_x_continuous("Stratum", breaks = strataSubset$x, labels = strataSubset$stratum) +
    ggplot2::scale_colour_manual(values = fiveColors) +
    ggplot2::facet_grid(database~., scales = "free_y") +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   panel.background = ggplot2::element_rect(fill = "#F0F0F0F0", colour = NA),
                   panel.grid.major.x = ggplot2::element_blank(),
                   panel.grid.major.y = ggplot2::element_line(colour = "#CCCCCC"),
                   axis.ticks = ggplot2::element_blank(),
                   legend.position = "top",
                   legend.title = ggplot2::element_blank(),
                   text = ggplot2::element_text(size = 20))
  if (metric %in% c("Mean precision (1/SE^2)", "Mean squared error (MSE)")) {
    plot <- plot + ggplot2::scale_y_log10(yLabel, labels = point)
  } else {
    plot <- plot + ggplot2::scale_y_continuous(yLabel, labels = point)
  }
  return(plot)
}
