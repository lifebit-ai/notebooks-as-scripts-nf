/*
 *
 *   This file is part of lifebit-ai/papermill-templates repository.
 *
 * Main lifebit-ai/papermill-templates script for running programmatically parameterised Jupyter Notebooks
 *
 * @author
 * Christina Chatzipantsiou
 */

log.info "Parameters Summary:"
log.info "====================================="
log.info "Plot type              : ${params.plot_type}"
log.info "Year                   : ${params.year}"
log.info "Continent to exclude   : ${params.continent_to_exclude}"
log.info "Design file            : ${params.design_file}"
log.info "\n"


def helpMessage() {
    log.info """
    Usage:
    The typical command for running the pipeline is as follows:
    nextflow run main.nf --plot_type "box" --continent_to_exclude "Oceania" --year 2007
    # or
    nextflow run main.nf --design_file assets/test_design_file.csv
    
    All arguments are parameters from the example vignette named ggbetweenstats.Rmd
    documenting the function ?ggstatsplot::ggbetweenstats.
    A link for this vignette can be found here:
    https://github.com/IndrajeetPatil/ggstatsplot/blob/master/vignettes/web_only/ggbetweenstats.Rmd

    Mandatory arguments:
    --plot_type              [str] Type of plot for the ggstatsplot::ggbetweenstats(plot.type = ..) function.
                                   Available: "box", "violin", "boxviolin"
                                   
    --year                   [int] Year of gapminder dataset records.
                                   Available:  years from 1952 to 2007, with 5 years intervals
      
    --continent_to_exclude   [str] Continent to exclude from gapminder comparison
                                   Available: "Asia", "Africa", "Oceania", "Europe", etc

    --design_file           [path] Path to csv design file with combination of the current
                                   pipeline parameters.
                                   Check assets/test_design_file.csv for an example file.
    """.stripIndent()
}

/*********************************
 *      CHANNELS SETUP           *
 *********************************/

// Notebook files staging
projectDir = workflow.projectDir
ch_jupyter_notebook =  Channel.value(file("${projectDir}/bin/ggbetweenstats.ipynb"))
ch_rmarkdown_notebook =  Channel.value(file("${projectDir}/bin/ggbetweenstats.Rmd"))

// Values
all_plot_types  = ['box', 'violin', 'boxviolin']
some_continents = ['Oceania','Europe','Africa']
few_years       = [1952, 1997]

// Input list .csv file of tissues to analyse
if (params.design_file.endsWith(".csv")) {
                 Channel.fromPath(params.design_file)
                        .ifEmpty { exit 1, "Input .csv list of input combinations of parameters not found at ${params.design_file}. Is the file path correct?" }
                        .splitCsv(sep: ',',  header: true)
                        .set { ch_design_file }
                        }

(ch_design_file_jupyter, ch_design_file_rmd) = ch_design_file.into(2)

/*********************************
 *          PROCESSES            *
 *********************************/

/*
 * Execute one notebook only when a design file is not provided
 */

if (!params.design_file) {
 process run_notebook {

    publishDir "${params.outdir}/", mode: 'copy'
    input:
    file(input_notebook_jupyter) from ch_jupyter_notebook

    output:
    file("${params.year}_${params.plot_type}_output.ipynb")

    script:
    """
    papermill  ${input_notebook_jupyter} ${params.year}_${params.plot_type}_output.ipynb \
    --kernel ir \
    -p year ${params.year} \
    -p plot_type "${params.plot_type}""  \
    -p continent_to_exclude "${params.continent_to_exclude}"  
    """
 }
}

/*
 * Execute many notebook, combinations of values
 */
 if (params.run_combinations) {
 process run_many_notebooks {
    tag "${year}-${plot_type}-${continent}"

    publishDir "${params.outdir}/", mode: 'copy'

    input:
    each year from few_years
    each continent from some_continents
    each plot_type from all_plot_types
    file(input_notebook_jupyter) from ch_jupyter_notebook

    output:
    file("${year}_${plot_type}_output.ipynb")

    script:
    """
    papermill ${input_notebook_jupyter} "${year}_${plot_type}"_output.ipynb \
    --kernel ir \
    -p year ${year} \
    -p plot_type ${plot_type}  \
    -p continent_to_exclude ${continent}
    """
    }
 }

 process run_from_design_file_notebooks_jupyter {
    tag "${year}-${plot_type}-${continent}"

    publishDir "${params.outdir}/jupyter", mode: 'copy'

    input:
    tuple val(plot_type), val(continent), val(year) from ch_design_file_jupyter
    file(input_notebook_jupyter) from ch_jupyter_notebook

    output:
    file("${year}_${plot_type}_output.ipynb")

    script:
    """
    papermill ${input_notebook_jupyter} "${year}_${plot_type}"_output.ipynb \
    --kernel ir \
    -p year ${year} \
    -p plot_type ${plot_type}  \
    -p continent_to_exclude ${continent}
    """
}

 if (params.run_rmd) {
 process run_from_design_file_notebooks_rmd {
    tag "${year}-${plot_type}-${continent}"

    publishDir "${params.outdir}/rmarkdown", mode: 'copy'

    input:
    tuple val(plot_type), val(continent), val(year) from ch_design_file_rmd
    file(input_notebook_rmarkdown) from ch_rmarkdown_notebook

    output:
    file("*output.html")

    script:
    """
    cp $input_notebook_rmarkdown output_${input_notebook_rmarkdown}
    Rscript -e "rmarkdown::render('output_${input_notebook_rmarkdown}', output_format = 'html_document', output_dir = '.' , list(year='$year',plot_type='$plot_type',continent_to_exclude='$continent'))"
    """
 }
}