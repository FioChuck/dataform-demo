
from airflow import models
from airflow.providers.google.cloud.operators.dataform import (
    DataformCreateCompilationResultOperator,
    DataformCreateWorkflowInvocationOperator,
)

DAG_ID = "dataform"
PROJECT_ID = "cf-data-analytics"
REPOSITORY_ID = "dataform-demo"
REGION = "us-central1"
GIT_COMMITISH = "main"

with models.DAG(
        DAG_ID,
        schedule=None,
        tags=['dataform'],
) as dag:

    create_compilation_result = DataformCreateCompilationResultOperator(
        task_id="create_compilation_result",
        project_id=PROJECT_ID,
        region=REGION,
        repository_id=REPOSITORY_ID,
        compilation_result={
            # "git_commitish": GIT_COMMITISH,
            "workspace": "cf-dev"
        },
    )
    create_workflow_invocation = DataformCreateWorkflowInvocationOperator(
        task_id='create_workflow_invocation',
        project_id=PROJECT_ID,
        region=REGION,
        repository_id=REPOSITORY_ID,
        workflow_invocation={
            "compilation_result": "{{ task_instance.xcom_pull('create_compilation_result')['name'] }}"
        },
    )


create_compilation_result >> create_workflow_invocation

if __name__ == "__main__":
    dag.cli()
    # dag.test()