{% materialization table, adapter='postgres' %}
    {{ exceptions.raise_compiler_error(
        "Materialización 'table' bloqueada: este proyecto permite solamente views."
    ) }}
{% endmaterialization %}

{% materialization incremental, adapter='postgres' %}
    {{ exceptions.raise_compiler_error(
        "Materialización 'incremental' bloqueada: este proyecto permite solamente views."
    ) }}
{% endmaterialization %}

{% materialization materialized_view, adapter='postgres' %}
    {{ exceptions.raise_compiler_error(
        "Materialización 'materialized_view' bloqueada: este proyecto permite solamente views."
    ) }}
{% endmaterialization %}

{% materialization snapshot, adapter='postgres' %}
    {{ exceptions.raise_compiler_error(
        "Snapshots bloqueados: este proyecto permite solamente views."
    ) }}
{% endmaterialization %}
