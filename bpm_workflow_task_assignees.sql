CREATE TABLE bpm_workflow_task_assignees (
    task_number   NUMBER        NOT NULL,
    assignee_id   VARCHAR2(200) NOT NULL,
    assignee_type VARCHAR2(50)  NOT NULL,
    CONSTRAINT bpm_task_assignees_pk
        PRIMARY KEY (task_number, assignee_id, assignee_type),
    CONSTRAINT bpm_task_assignees_fk
        FOREIGN KEY (task_number)
        REFERENCES bpm_workflow_tasks (task_number)
);
